import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import AuthNavigator from './AuthNavigator';

const MainStack = createNativeStackNavigator();

const MainNavigator = () => {
  return (
    <MainStack.Navigator>
      <MainStack.Screen
        name="AuthNavigator"
        component={AuthNavigator}
        options={{ headerShown: false }}
      />
    </MainStack.Navigator>
  );
};

export default MainNavigator;
