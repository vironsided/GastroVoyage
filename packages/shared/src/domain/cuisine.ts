export interface Cuisine {
  id: string;
  countryId: string;
  name: string;
  description: string | null;
  signatureDish: string | null;
  imageUrl: string | null;
}
