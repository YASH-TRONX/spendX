import { FlashList } from '@shopify/flash-list';
import React from 'react';
import { Text, View } from 'react-native';
import Seperator from '../Seperator';

const DATA = [
  {
    title: 'Money Transfer',
    time: '12:35 PM',
    amount: '-₹450',
    type: 'deducted',
  },
  {
    title: 'Paypal',
    time: '11:35 PM',
    amount: '+₹1200',
    type: 'credited',
  },
  {
    title: 'Money Transfer',
    time: '12:35 PM',
    amount: '-₹450',
    type: 'deducted',
  },
  {
    title: 'Paypal',
    time: '11:35 PM',
    amount: '+₹1200',
    type: 'credited',
  },
  {
    title: 'Money Transfer',
    time: '12:35 PM',
    amount: '-₹450',
    type: 'deducted',
  },
  {
    title: 'Paypal',
    time: '11:35 PM',
    amount: '+₹1200',
    type: 'credited',
  },
  {
    title: 'Money Transfer',
    time: '12:35 PM',
    amount: '-₹450',
    type: 'deducted',
  },
  {
    title: 'Paypal',
    time: '11:35 PM',
    amount: '+₹1200',
    type: 'credited',
  },
  {
    title: 'Money Transfer',
    time: '12:35 PM',
    amount: '-₹450',
    type: 'deducted',
  },
  {
    title: 'Paypal',
    time: '11:35 PM',
    amount: '+₹1200',
    type: 'credited',
  },
];

const UserLogo = () => {
  return (
    <View
      style={{
        width: 50,
        height: 50,
        borderRadius: 5,
        backgroundColor: '#EEE5FF',
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      <View
        style={{
          width: 30,
          height: 30,
          borderRadius: 15,
          backgroundColor: 'white',
        }}
      />
    </View>
  );
};

const TxnList = () => {
  const ListItem = (ListItem: any) => {
    const { item } = ListItem;
    return (
      <View
        style={{
          flexDirection: 'row',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <UserLogo />
          <Seperator widthSpaceValue={15} />
          <View>
            <Text style={{ fontSize: 15, color: 'black', fontWeight: 500 }}>{item.title}</Text>
            <Seperator heightSpaceValue={5} />
            <Text style={{ fontSize: 12, color: 'grey' }}>{item.time}</Text>
          </View>
        </View>
        <Text
          style={{
            fontSize: 15,
            color: item.type === 'deducted' ? 'red' : 'green',
          }}
        >
          {item.amount}
        </Text>
      </View>
    );
  };

  return (
    <View
      // onLayout={e => console.log(e?.nativeEvent?.layout?.height, 'gggg====')}
      style={{ flex: 1 }}
    >
      <FlashList
        data={DATA}
        renderItem={ListItem}
        showsVerticalScrollIndicator={false}
        ItemSeparatorComponent={() => <Seperator heightSpaceValue={25} />}
      />
    </View>
  );
};

export default TxnList;
