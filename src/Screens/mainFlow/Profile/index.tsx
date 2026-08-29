import React from 'react';
import DeviceInfo from 'react-native-device-info';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Header } from '../../../Components';
import { Menu } from '../../../Images';

const Profile = () => {
  const hasNotch = DeviceInfo.hasNotch();
  return (
    <SafeAreaView
      style={{ flex: 1, marginTop: hasNotch ? 5 : 20, marginHorizontal: 25 }}
    >
      <Header
        LeftIcon={<Menu width={18} height={18} />}
        LeftIconOnPress={() => console.log('gta123')}
        RightIconOnPress={() => console.log('gta456')}
        title="Profile"
      />
    </SafeAreaView>
  );
};

export default Profile;
