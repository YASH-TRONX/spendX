import { View } from 'react-native';

interface iSeperator {
  heightSpaceValue?: number;
  widthSpaceValue?: number;
}

const Seperator = (props: iSeperator) => {
  const { heightSpaceValue = 0, widthSpaceValue = 0 } = props;
  return (
    <View
      style={{ paddingTop: heightSpaceValue, paddingRight: widthSpaceValue }}
    />
  );
};

export default Seperator;
