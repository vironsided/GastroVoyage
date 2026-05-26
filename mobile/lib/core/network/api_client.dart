import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/couples/data/couple_models.dart';
import 'package:mobile/features/notifications/data/notification_model.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/features/social/data/social_models.dart';

// ─── Auth result ──────────────────────────────────────────────────────────────

class AuthResult {
  const AuthResult({
    required this.userId,
    required this.email,
    required this.displayName,
    this.homeCity,
    this.accessToken,
    this.refreshToken,
    required this.emailConfirmed,
  });

  final String userId;
  final String email;
  final String displayName;
  final String? homeCity;
  final String? accessToken;
  final String? refreshToken;
  final bool emailConfirmed;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        userId: j['user_id'] as String,
        email: j['email'] as String,
        displayName: j['display_name'] as String,
        homeCity: j['home_city'] as String?,
        accessToken: j['access_token'] as String?,
        refreshToken: j['refresh_token'] as String?,
        emailConfirmed: j['email_confirmed'] as bool? ?? false,
      );
}

// ─── Exceptions ────────────────────────────────────────────────────────────────

class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = 'Session expired']);
  final String message;
  @override
  String toString() => 'UnauthorizedException: $message';
}

// ─── API client ───────────────────────────────────────────────────────────────

/// Default base URL chosen for an Android emulator hitting host loopback.
/// Override at run/build time:
///   `flutter run --dart-define=API_URL=https://api.gastrovoyage.app`
const String _kDefaultBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

typedef TokenGetter = String? Function();
typedef TokensRefreshed = void Function(String accessToken, String refreshToken);

class ApiClient {
  ApiClient({
    String? baseUrl,
    TokenGetter? getToken,
    TokenGetter? getRefreshToken,
    this.onTokensRefreshed,
  })  : _getToken = getToken,
        _getRefreshToken = getRefreshToken,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? _kDefaultBaseUrl,
            // Generous timeouts so a Render-free cold start (~30–60s after
            // 15min of idle) doesn't surface as "Cannot connect to server".
            // Warm requests still complete in <1s on the normal happy path.
            connectTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 60),
          ),
        ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _getToken?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final is401 = e.response?.statusCode == 401;
        final isAuthCall = e.requestOptions.path.contains('/auth/');
        final alreadyRetried = e.requestOptions.extra['__retried'] == true;

        // An expired access token: silently refresh once and replay the
        // request, so the user never sees a spurious "session expired".
        if (is401 && !isAuthCall && !alreadyRetried) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            try {
              final opts = e.requestOptions;
              opts.extra['__retried'] = true;
              final res = await _dio.fetch<dynamic>(opts);
              return handler.resolve(res);
            } catch (_) {
              // fall through to the 401 rejection below
            }
          }
        }

        // Normalize 401 into a typed exception so callers / providers can
        // react (logout, redirect to login) without inspecting Dio internals.
        if (is401) {
          handler.reject(DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: const UnauthorizedException(),
          ));
          return;
        }
        handler.next(e);
      },
    ));
  }

  final Dio _dio;
  final TokenGetter? _getToken;
  final TokenGetter? _getRefreshToken;

  /// Invoked with a fresh token pair after a successful silent refresh, so
  /// the auth state and persistent storage can be updated.
  final TokensRefreshed? onTokensRefreshed;

  /// De-dupes concurrent refreshes: many requests may 401 at once, but only
  /// one `/auth/refresh` call should go out.
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshToken() {
    return _refreshInFlight ??=
        _performRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _getRefreshToken?.call();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      // A bare Dio so this call never recurses through the auth interceptor.
      final res = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl))
          .post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newAccess = res.data?['access_token'] as String?;
      final newRefresh = res.data?['refresh_token'] as String?;
      if (newAccess == null || newAccess.isEmpty) return false;
      onTokensRefreshed?.call(newAccess, newRefresh ?? refreshToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Profile ─────────────────────────────────────────────────────────────────

  Future<UserProfile> profile() async {
    final res = await _dio.get('/profile/me');
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateProfile({
    String? displayName,
    String? homeCity,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (homeCity != null) data['home_city'] = homeCity;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    await _dio.patch('/profile/me', data: data);
  }

  /// Permanently deletes the authenticated user and all their data.
  /// Irreversible — callers must confirm with the user first.
  Future<void> deleteAccount() async {
    await _dio.delete('/profile/me');
  }

  // ── Countries ───────────────────────────────────────────────────────────────

  Future<List<Country>> countries({String? region, bool? visited}) async {
    final params = <String, dynamic>{};
    if (region != null) params['region'] = region;
    if (visited != null) params['visited'] = visited;
    final res = await _dio.get('/countries', queryParameters: params);
    return (res.data as List)
        .map((e) => Country.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Country>> mapCountries() async {
    final res = await _dio.get('/map/countries');
    return (res.data as List)
        .map((e) => Country.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Wishlist ("Want to try") ────────────────────────────────────────────────

  /// The caller's wishlist, newest-first. Each backend row is joined with the
  /// `countries` table so the mobile UI can render a polaroid pin straight
  /// away; this client unwraps the nested `country` object and surfaces a
  /// flat `List<Country>`. A not-yet-migrated backend returns `[]`.
  Future<List<Country>> wishlist() async {
    final res = await _dio.get('/wishlist');
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((row) {
          final country = row['country'];
          if (country is Map<String, dynamic>) {
            return Country.fromJson(country);
          }
          return null;
        })
        .whereType<Country>()
        .toList();
  }

  /// Bookmarks [countryId] as "want to try". Idempotent on the backend —
  /// re-adding an existing pair is a no-op success, so the mobile UI's
  /// optimistic pin toggle can fire this without worrying about duplicates.
  Future<void> addToWishlist(String countryId) async {
    await _dio.post('/wishlist', data: {'country_id': countryId});
  }

  /// Un-bookmarks [countryId]. Idempotent — calling on a pair that's not on
  /// the wishlist still returns success.
  Future<void> removeFromWishlist(String countryId) async {
    await _dio.delete('/wishlist/$countryId');
  }

  // ── Visits ──────────────────────────────────────────────────────────────────

  Future<List<Visit>> visits() async {
    final res = await _dio.get('/visits');
    return (res.data as List)
        .map((e) => Visit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Visit> createVisit({
    required String countryId,
    required String notes,
    required int rating,
    required String visitedOn,
    String? photoUrl,
    String? restaurantName,
    int? atmosphereRating,
    int? serviceRating,
    int? valueRating,
    int? dishRating,
    bool? withPartner,
  }) async {
    final data = <String, dynamic>{
      'country_id': countryId,
      'notes': notes,
      'rating': rating,
      'visited_on': visitedOn,
    };
    if (photoUrl != null && photoUrl.isNotEmpty) data['photo_path'] = photoUrl;
    if (restaurantName != null && restaurantName.isNotEmpty) {
      data['restaurant_name'] = restaurantName;
    }
    if (atmosphereRating != null) data['atmosphere_rating'] = atmosphereRating;
    if (serviceRating != null) data['service_rating'] = serviceRating;
    if (valueRating != null) data['value_rating'] = valueRating;
    if (dishRating != null) data['dish_rating'] = dishRating;
    if (withPartner != null) data['with_partner'] = withPartner;
    final res = await _dio.post('/visits', data: data);
    return Visit.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Visit> updateVisit({
    required String visitId,
    String? notes,
    int? rating,
    String? visitedOn,
    String? photoPath,
    String? restaurantName,
    int? atmosphereRating,
    int? serviceRating,
    int? valueRating,
    int? dishRating,
    bool? withPartner,
  }) async {
    final data = <String, dynamic>{};
    if (notes != null) data['notes'] = notes;
    if (rating != null) data['rating'] = rating;
    if (visitedOn != null) data['visited_on'] = visitedOn;
    if (photoPath != null) data['photo_path'] = photoPath;
    if (restaurantName != null && restaurantName.isNotEmpty) {
      data['restaurant_name'] = restaurantName;
    }
    if (atmosphereRating != null) data['atmosphere_rating'] = atmosphereRating;
    if (serviceRating != null) data['service_rating'] = serviceRating;
    if (valueRating != null) data['value_rating'] = valueRating;
    if (dishRating != null) data['dish_rating'] = dishRating;
    if (withPartner != null) data['with_partner'] = withPartner;
    final res = await _dio.patch('/visits/$visitId', data: data);
    return Visit.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteVisit(String visitId) async {
    await _dio.delete('/visits/$visitId');
  }

  // ── Badges ──────────────────────────────────────────────────────────────────

  Future<List<CuisineBadge>> badges() async {
    final res = await _dio.get('/badges');
    return (res.data as List)
        .map((e) => CuisineBadge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Uploads ─────────────────────────────────────────────────────────────────

  /// Upload a picked photo. Accepts an [XFile] so it works identically on
  /// native (`xfile.path` is a real filesystem path) and web (`xfile.path`
  /// is a blob: URL we can't open through `dart:io`). Internally we read
  /// the bytes through [XFile.readAsBytes] and send a `MultipartFile.fromBytes`
  /// so the call path is platform-agnostic.
  Future<String> uploadPhoto(XFile xfile) async {
    final bytes = await xfile.readAsBytes();
    final filename = xfile.name.isNotEmpty ? xfile.name : 'upload.jpg';
    // Pick a content-type the backend will accept. XFile.mimeType is
    // sometimes empty (image_picker on iOS web in particular), so fall back
    // to inferring from the extension.
    final mime = (xfile.mimeType?.isNotEmpty ?? false)
        ? xfile.mimeType!
        : _mimeFromFilename(filename);
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(mime),
      ),
    });
    final res = await _dio.post('/uploads', data: formData);
    return res.data['url'] as String;
  }

  /// Map a filename to one of the MIME types the backend's `/uploads`
  /// route allows. Falls back to `image/jpeg` since that's by far the most
  /// common gallery format and matches the backend's default.
  String _mimeFromFilename(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  // ── Auth (no token required) ────────────────────────────────────────────────

  /// Lightweight ping used to wake a sleeping backend (Render free spins down
  /// after 15 minutes of inactivity). Caller should treat any exception as a
  /// no-op — this is a latency hint, not a connectivity probe.
  Future<void> healthCheck() async {
    await _dio.get('/health');
  }

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    return AuthResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/signin', data: {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// Exchanges a native Google/Apple provider ID token for a GastroVoyage
  /// session. The backend hands the token to Supabase, which verifies it
  /// with the provider and issues its own JWT pair — so the app only ever
  /// holds a Supabase session, never a raw Google/Apple credential.
  ///
  /// [provider] must be `'google'` or `'apple'`. [accessToken] is the
  /// provider's OAuth access token when available (Google), and
  /// [displayName] carries the user's name on Apple's first sign-in (Apple
  /// only sends it once).
  Future<AuthResult> oauthSignIn({
    required String provider,
    required String idToken,
    String? accessToken,
    String? displayName,
  }) async {
    final res = await _dio.post('/auth/oauth', data: {
      'provider': provider,
      'id_token': idToken,
      if (accessToken != null && accessToken.isNotEmpty)
        'access_token': accessToken,
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
    });
    return AuthResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> resendVerification(String email) async {
    await _dio.post('/auth/resend', data: {'email': email});
  }

  // ── Social: follow graph ────────────────────────────────────────────────────

  /// Sends a follow request to [followingId]. Returns the resulting edge
  /// status — `pending` when the target's passport is followers/private, or
  /// `accepted` when it's public (auto-accepted).
  Future<FollowStatus> followUser(String followingId) async {
    final res = await _dio.post(
      '/social/follow',
      data: {'following_id': followingId},
    );
    final data = (res.data as Map<String, dynamic>?) ?? const {};
    return FollowStatusX.fromWire(data['status'] as String?);
  }

  /// Removes the follow edge toward [followingId] — either un-following an
  /// accepted user or cancelling a still-pending request.
  Future<void> unfollowUser(String followingId) async {
    await _dio.delete('/social/follow/$followingId');
  }

  /// Accepts an incoming follow request from [followerId].
  Future<void> acceptFollow(String followerId) async {
    await _dio.post('/social/follow/$followerId/accept');
  }

  /// Declines an incoming follow request from [followerId].
  Future<void> declineFollow(String followerId) async {
    await _dio.post('/social/follow/$followerId/decline');
  }

  /// People the current user follows (each carries its edge `status`).
  Future<List<SocialUser>> following() async {
    final res = await _dio.get('/social/following');
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SocialUser.fromJson)
        .toList();
  }

  /// People who follow (or have requested to follow) the current user. The
  /// list mixes `pending` and `accepted` edges — callers split on `status`.
  Future<List<SocialUser>> followers() async {
    final res = await _dio.get('/social/followers');
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SocialUser.fromJson)
        .toList();
  }

  /// Searches users by display name. An empty / whitespace [q] short-circuits
  /// to an empty list without hitting the network.
  Future<List<SocialUser>> searchUsers(String q) async {
    final term = q.trim();
    if (term.isEmpty) return const [];
    final res = await _dio.get(
      '/social/users/search',
      queryParameters: {'q': term},
    );
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SocialUser.fromJson)
        .toList();
  }

  // ── Social: privacy ─────────────────────────────────────────────────────────

  /// Reads the current user's passport visibility setting.
  Future<PassportVisibility> getPrivacy() async {
    final res = await _dio.get('/social/privacy');
    final data = (res.data as Map<String, dynamic>?) ?? const {};
    return PassportVisibilityX.fromWire(
        data['passport_visibility'] as String?);
  }

  /// Updates the current user's passport visibility. Returns the persisted
  /// value echoed back by the backend.
  Future<PassportVisibility> setPrivacy(PassportVisibility visibility) async {
    final res = await _dio.patch(
      '/social/privacy',
      data: {'passport_visibility': visibility.wire},
    );
    final data = (res.data as Map<String, dynamic>?) ?? const {};
    return PassportVisibilityX.fromWire(
        data['passport_visibility'] as String?);
  }

  // ── Social: passport inspection ─────────────────────────────────────────────

  /// Fetches another user's public passport. Translates the backend's access
  /// errors into typed exceptions: 403 → [PassportPrivateException], 404 →
  /// [PassportNotFoundException].
  Future<PublicPassport> viewPassport(String userId) async {
    try {
      final res = await _dio.get('/social/passport/$userId');
      return PublicPassport.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403) throw const PassportPrivateException();
      if (code == 404) throw const PassportNotFoundException();
      rethrow;
    }
  }

  // ── Social: stories & feed ──────────────────────────────────────────────────

  /// Publishes a culinary story. Plumbing for a later round — the story feed
  /// UI is not part of round 1.
  Future<Story> createStory({
    required String photoUrl,
    String? caption,
    String? countryId,
  }) async {
    final data = <String, dynamic>{'photo_url': photoUrl};
    if (caption != null && caption.isNotEmpty) data['caption'] = caption;
    if (countryId != null && countryId.isNotEmpty) {
      data['country_id'] = countryId;
    }
    final res = await _dio.post('/social/stories', data: data);
    return Story.fromJson(res.data as Map<String, dynamic>);
  }

  /// The current user's social feed (stories from people they follow).
  Future<List<Story>> socialFeed() async {
    final res = await _dio.get('/social/feed');
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Story.fromJson)
        .toList();
  }

  /// Records that the current user just saw [storyId]. Idempotent on the
  /// backend (upsert on `(story_id, viewer_id)`) and intentionally
  /// fire-and-forget — a transient network blip must never interrupt the
  /// full-screen story viewer, so all exceptions are swallowed.
  Future<void> markStoryViewed(String storyId) async {
    if (storyId.isEmpty) return;
    try {
      await _dio.post('/social/stories/$storyId/view');
    } catch (_) {
      // Swallow: a missed view is harmless; the next visit will retry.
    }
  }

  /// Owner-only list of who has viewed [storyId], newest-first.
  /// Throws the underlying [DioException] on 403/404 so the caller can render
  /// a friendly error state.
  Future<List<StoryViewerEntry>> storyViewers(String storyId) async {
    final res = await _dio.get('/social/stories/$storyId/viewers');
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StoryViewerEntry.fromJson)
        .toList();
  }

  /// Upserts the current user's reaction emoji on [storyId]. Returns the
  /// persisted emoji echoed back by the backend (useful when a future server
  /// version sanitises the input).
  ///
  /// Throws [DioException] on transport errors so the caller can roll back
  /// any optimistic UI update; reacting to your own story succeeds silently
  /// on the backend without enqueuing a notification.
  Future<String> reactToStory(String storyId, String emoji) async {
    final res = await _dio.post(
      '/social/stories/$storyId/react',
      data: {'emoji': emoji},
    );
    final data = (res.data as Map<String, dynamic>?) ?? const {};
    return (data['emoji'] as String?) ?? emoji;
  }

  /// Deletes the current user's reaction on [storyId]. Idempotent on the
  /// backend — calling it twice is harmless.
  Future<void> unreactToStory(String storyId) async {
    await _dio.delete('/social/stories/$storyId/react');
  }

  /// Owner-only list of every reaction on [storyId], newest-first. Mirrors
  /// [storyViewers] in shape. A not-yet-migrated backend returns `[]`.
  Future<List<StoryReaction>> storyReactions(String storyId) async {
    final res = await _dio.get('/social/stories/$storyId/reactions');
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StoryReaction.fromJson)
        .toList();
  }

  /// Lists every comment on [storyId], oldest-first. Open to any authenticated
  /// caller — the comments thread is shared content like the story itself. A
  /// not-yet-migrated backend returns `[]` rather than erroring.
  Future<List<StoryComment>> storyComments(String storyId) async {
    final res = await _dio.get('/social/stories/$storyId/comments');
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StoryComment.fromJson)
        .toList();
  }

  /// Posts a comment on [storyId]. The backend bounds [text] to 1..280 chars
  /// after trimming; an empty or oversized string surfaces as a [DioException]
  /// the caller can pattern-match. Returns the inserted row with the actor
  /// profile joined in — usable for an instant append to the sheet's list.
  Future<StoryComment> commentOnStory(String storyId, String text) async {
    final res = await _dio.post(
      '/social/stories/$storyId/comment',
      data: {'text': text},
    );
    return StoryComment.fromJson(res.data as Map<String, dynamic>);
  }

  /// Deletes [commentId]. Only the commenter or the story owner is allowed;
  /// any other caller surfaces a 403 [DioException]. A second delete returns
  /// 404 because the row is already gone.
  Future<void> deleteStoryComment(String commentId) async {
    await _dio.delete('/social/stories/comments/$commentId');
  }

  // ── Couples' Culinary Journey ───────────────────────────────────────────────

  /// How many weeks of the couples' journey the current user has completed.
  /// A not-yet-migrated backend reports `0` rather than erroring.
  Future<int> getCouplesProgress() async {
    final res = await _dio.get('/couples/progress');
    final data = (res.data as Map<String, dynamic>?) ?? const {};
    final weeks = (data['completed_weeks'] as num?)?.toInt() ?? 0;
    return weeks < 0 ? 0 : weeks;
  }

  /// Persists the couple's journey progress. Negative values are clamped to 0.
  /// Returns the value echoed back by the backend.
  Future<int> setCouplesProgress(int completedWeeks) async {
    final clamped = completedWeeks < 0 ? 0 : completedWeeks;
    final res = await _dio.put(
      '/couples/progress',
      data: {'completed_weeks': clamped},
    );
    final data = (res.data as Map<String, dynamic>?) ?? const {};
    final weeks = (data['completed_weeks'] as num?)?.toInt() ?? clamped;
    return weeks < 0 ? 0 : weeks;
  }

  // ── Couples: partner linking ───────────────────────────────────────────────

  /// Fetches the current user's active couple (pending or accepted), or null
  /// when unlinked. A not-yet-migrated backend returns null instead of 500.
  Future<Couple?> myCouple() async {
    final res = await _dio.get('/couples/me');
    final data = (res.data as Map<String, dynamic>?) ?? const {};
    final raw = data['couple'];
    if (raw is Map<String, dynamic>) {
      return Couple.fromJson(raw);
    }
    return null;
  }

  /// Send a couple invite to another user. Backend rejects when either side
  /// is already linked (409) — caller should surface that to the UI.
  Future<void> invitePartner(String targetUserId) async {
    await _dio.post('/couples/invite/$targetUserId');
  }

  /// Accept the pending incoming invite, if any. 404 when there's nothing to
  /// accept, 403 when the viewer is the inviter (only invitee can accept).
  Future<void> acceptCouple() async {
    await _dio.post('/couples/accept');
  }

  /// Decline the pending incoming invite. Marks the row 'ended' server-side.
  Future<void> declineCouple() async {
    await _dio.post('/couples/decline');
  }

  /// Unlink the current active couple. No-op when there isn't one.
  Future<void> unlinkCouple() async {
    await _dio.delete('/couples/me');
  }

  /// Combined stats for the current couple. Reports `active: false` when
  /// there's no accepted link, so the dashboard card knows to hide itself.
  Future<CoupleStats> coupleStats() async {
    final res = await _dio.get('/couples/stats');
    return CoupleStats.fromJson(
        (res.data as Map<String, dynamic>?) ?? const {});
  }

  // ── Notifications inbox ─────────────────────────────────────────────────────

  /// Lists the current user's notifications, newest first. A not-yet-migrated
  /// backend returns `[]` rather than erroring, so callers can render the
  /// empty state instead of an error card.
  Future<List<AppNotification>> notifications({int limit = 50}) async {
    final res = await _dio.get(
      '/notifications',
      queryParameters: {'limit': limit},
    );
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  /// Count of the current user's unread notifications. A not-yet-migrated
  /// backend reports `0` rather than erroring.
  Future<int> unreadCount() async {
    final res = await _dio.get('/notifications/unread_count');
    final data = (res.data as Map<String, dynamic>?) ?? const {};
    final count = (data['count'] as num?)?.toInt() ?? 0;
    return count < 0 ? 0 : count;
  }

  /// Marks notifications as read. Pass [all] to clear the entire inbox, or
  /// [ids] for a targeted subset. The backend always scopes by the caller's
  /// user_id — the request body cannot widen that boundary.
  Future<void> markRead({List<String>? ids, bool all = false}) async {
    final body = <String, dynamic>{};
    if (all) {
      body['all'] = true;
    } else {
      body['ids'] = ids ?? const <String>[];
    }
    await _dio.post('/notifications/mark_read', data: body);
  }
}
