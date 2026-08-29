/* eslint-disable react/no-unstable-nested-components */
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import React from 'react';
import {Cashbook, Home, Profile, Transactions} from '../Screens/mainFlow';
import { Bar_Graph_Logo, Home_Logo, Options_Logo, Sets_Logo } from '../Images';
import DeviceInfo from 'react-native-device-info';

const DashboardBottomStack = createBottomTabNavigator();
const hasNotch = DeviceInfo.hasNotch();

const DashboardNavigator = () => {
  return (
    <DashboardBottomStack.Navigator
      screenOptions={({ route }) => ({
        //{ focused, color, size }
        tabBarIcon: () => {

          // if (route.name === 'Home') {
          //   iconName = focused ? 'home' : 'home-outline';
          // } else if (route.name === 'Settings') {
          //   iconName = focused ? 'settings' : 'settings-outline';
          // }

          if(route.name === "Home") {
            return <Home_Logo width={22} height={22} />;
          } else if(route.name === "History") {
            return <Bar_Graph_Logo width={22} height={22} />;
          } else if(route.name === "Wallet") {
            return <Sets_Logo width={22} height={22} />;
          } else {
            return <Options_Logo width={22} height={22} />;
          } 

        },
        tabBarActiveTintColor: '#7F3DFF',
        tabBarInactiveTintColor: 'gray',
        tabBarShowLabel: false,
        tabBarIconStyle: hasNotch && {top: 20}
      })}
    >
      <DashboardBottomStack.Screen
        name="Home"
        component={Home}
        options={{ headerShown: false }}
      />
      <DashboardBottomStack.Screen
        name="History"
        component={Transactions}
        options={{ headerShown: false }}
      />
      <DashboardBottomStack.Screen
        name="Wallet"
        component={Cashbook}
        options={{ headerShown: false }}
      />
      <DashboardBottomStack.Screen
        name="Settings"
        component={Profile}
        options={{ headerShown: false }}
      />
    </DashboardBottomStack.Navigator>
  );
};

export default DashboardNavigator;
