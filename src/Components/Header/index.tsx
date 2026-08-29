import React from 'react';
import { Pressable, Text, View } from 'react-native';

interface iHeader {
  title: string;
  LeftIcon?: any;
  LeftIconOnPress?: () => void;
  RightIconOnPress?: () => void;
  RightIcon?: any;
}

const Header = (props: iHeader) => {
  const { title, LeftIcon, RightIcon, LeftIconOnPress, RightIconOnPress } =
    props;
  return (
    <View
      style={{
        flexDirection: 'row',
        justifyContent: 'center',
        alignItems: 'center',
        padding: 10,
      }}
    >
      {LeftIcon && (
        <Pressable
          style={{
            position: 'absolute',
            left: 0,
            padding: 12,
            backgroundColor: '#EEE5FF',
            borderRadius: 10,
          }}
          onPress={LeftIconOnPress}
        >
          {LeftIcon}
        </Pressable>
      )}
      <Text style={{ fontSize: 18, fontWeight: 500 }}>{title}</Text>
      {RightIcon && (
        <Pressable
          style={{
            position: 'absolute',
            right: 0,
            padding: 10,
            backgroundColor: '#EEE5FF',
            borderRadius: 10,
          }}
          onPress={RightIconOnPress}
        >
          {RightIcon}
        </Pressable>
      )}
    </View>
  );
};

export default Header;
