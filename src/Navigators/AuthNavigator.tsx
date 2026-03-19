import { createNativeStackNavigator } from '@react-navigation/native-stack';
import React from 'react';
import GettingStarted from '../Screens/userAuth/GettingStarted';

const AuthStack = createNativeStackNavigator();

const AuthNavigator = () => {
  return (
    <AuthStack.Navigator>
      <AuthStack.Screen
        name="gettingStarted"
        component={GettingStarted}
        options={{ headerShown: false }}
      />
    </AuthStack.Navigator>
  );
};

export default AuthNavigator;
