import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import AuthNavigator from './AuthNavigator';
import DashboardNavigator from './DashboardNavigator';

const MainStack = createNativeStackNavigator();

const MainNavigator = () => {
  return (
    <MainStack.Navigator>
      <MainStack.Screen
        name="DashboardNavigator"
        component={DashboardNavigator}
        options={{ headerShown: false }}
      />
      <MainStack.Screen
        name="AuthNavigator"
        component={AuthNavigator}
        options={{ headerShown: false }}
      />
    </MainStack.Navigator>
  );
};

export default MainNavigator;
