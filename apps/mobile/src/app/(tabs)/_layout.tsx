import { Tabs } from 'expo-router';
import { Text } from 'react-native';

const TabIcon = ({ symbol, focused }: { symbol: string; focused: boolean }) => (
  <Text
    style={{
      fontSize: 21,
      opacity: focused ? 1 : 0.65,
      textShadowColor: focused ? 'rgba(75, 235, 255, 0.75)' : 'transparent',
      textShadowOffset: { width: 0, height: 0 },
      textShadowRadius: focused ? 9 : 0,
    }}
  >
    {symbol}
  </Text>
);

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          position: 'absolute',
          left: 10,
          right: 10,
          bottom: 10,
          borderRadius: 18,
          backgroundColor: 'rgba(15, 30, 55, 0.86)',
          borderTopWidth: 0,
          borderWidth: 1,
          borderColor: 'rgba(106, 211, 255, 0.2)',
          height: 74,
          paddingBottom: 8,
          paddingTop: 8,
          elevation: 10,
        },
        tabBarActiveTintColor: '#69efff',
        tabBarInactiveTintColor: '#9bb4c6',
        tabBarLabelStyle: { fontSize: 12, letterSpacing: 0.4, fontFamily: 'Inter_500Medium' },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Карта',
          tabBarIcon: ({ focused }) => <TabIcon symbol="🗺" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="passport"
        options={{
          title: 'Паспорт',
          tabBarIcon: ({ focused }) => <TabIcon symbol="📖" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Профиль',
          tabBarIcon: ({ focused }) => <TabIcon symbol="👤" focused={focused} />,
        }}
      />
    </Tabs>
  );
}
