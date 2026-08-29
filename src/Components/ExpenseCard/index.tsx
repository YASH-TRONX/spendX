import React from 'react';
import { Text, View } from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import {
    Arrow_Circle_Down,
    Arrow_Circle_Up,
    Down,
    More_Horizontal,
} from '../../Images';
import Seperator from '../Seperator';

const ExpenseCard = () => {
  return (
    <LinearGradient
      start={{ x: 0, y: 1 }}
      end={{ x: 1, y: 0 }}
      colors={['#7089FF', '#B366FF', '#FF8164']}
      style={{
        borderRadius: 30,
      }}
    >
      <View style={{ paddingVertical: 20, paddingHorizontal: 25 }}>
        <View
          style={{
            flexDirection: 'row',
            justifyContent: 'space-between',
            alignItems: 'flex-start',
          }}
        >
          <View>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <Text style={{ color: '#FFFF' }}>Total Balance</Text>
              <Seperator widthSpaceValue={8} />
              <Down color={'#ffff'} width={10} height={10} />
            </View>
            <Seperator heightSpaceValue={8} />
            <Text style={{ color: '#FFFF', fontSize: 26 }}>₹5,257.00</Text>
          </View>
          <More_Horizontal width={20} height={20} />
        </View>
        <Seperator heightSpaceValue={50} />
        <View
          style={{
            flexDirection: 'row',
            justifyContent: 'space-between',
            paddingHorizontal: 10,
          }}
        >
          <View>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <Arrow_Circle_Down width={20} height={20} />
              <Seperator widthSpaceValue={3} />
              <Text style={{ color: '#FFFF', fontSize: 15 }}>Income</Text>
            </View>
            <Seperator heightSpaceValue={5} />
            <Text style={{ marginStart: 3, color: '#FFFF', fontSize: 20 }}>
              ₹2,350.00
            </Text>
          </View>
          <View>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <Arrow_Circle_Up width={20} height={20} />
              <Seperator widthSpaceValue={3} />
              <Text style={{ color: '#FFFF', fontSize: 15 }}>Expenses</Text>
            </View>
            <Seperator heightSpaceValue={5} />
            <Text style={{ marginStart: 3, color: '#FFFF', fontSize: 20 }}>
              ₹950.00
            </Text>
          </View>
        </View>
      </View>
    </LinearGradient>
  );
};

export default ExpenseCard;
