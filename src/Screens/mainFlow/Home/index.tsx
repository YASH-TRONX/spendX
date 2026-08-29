import React from 'react';
import { SafeAreaView } from 'react-native-safe-area-context';
import {
  ExpenseCard,
  Header,
  Seperator,
  TxnList,
  TxnListHeader,
} from '../../../Components';
import { Bell_Notification, Menu } from '../../../Images';
import DeviceInfo from 'react-native-device-info';

const Home = () => {
  const hasNotch = DeviceInfo.hasNotch();
  return (
    <SafeAreaView style={{ flex: 1, marginTop: hasNotch ? 5 : 20, marginHorizontal: 25 }}>
        <Header
          LeftIcon={<Menu width={18} height={18} />}
          RightIcon={<Bell_Notification width={22} height={22} />}
          LeftIconOnPress={() => console.log('gta123')}
          RightIconOnPress={() => console.log('gta456')}
          title="Home"
        />
        <Seperator heightSpaceValue={25} />
        <ExpenseCard />
        <Seperator heightSpaceValue={25} />
        <TxnListHeader />
        <Seperator heightSpaceValue={25} />
        <TxnList />
    </SafeAreaView>
  );
};

export default Home;
