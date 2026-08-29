import React from "react";
import { Pressable, Text, View } from "react-native";

const TxnListHeader = () => {
    return (
        <View style={{flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginHorizontal: 5}}>
            <Text style={{fontSize: 22, fontWeight: 500}}>Transactions</Text>
            <Pressable>
            <Text style={{fontSize: 12, fontWeight: 400, color: 'grey'}}>See All</Text>
            </Pressable>
        </View>
    )
};

export default TxnListHeader;