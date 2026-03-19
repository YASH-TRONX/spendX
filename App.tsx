import React, { useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { MainNavigator } from './src/Navigators';
import SplashScreen from 'react-native-splash-screen';

const App = () => {
  useEffect(() => {
    SplashScreen.hide();
  }, []);

  return (
    <NavigationContainer>
      <MainNavigator />
    </NavigationContainer>
  );
};

export default App;
