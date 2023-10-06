import Lending_Borrow from "../../contracts/L&B/L&B.cdc"

pub fun main(address: Address): [UInt64] {
    
    let bucketListRef: Capability<&Lending_Borrow.bucketList> = getAccount(address).getCapability<&Lending_Borrow.bucketList>(Lending_Borrow.bucketListPublicPath)

    if(bucketListRef.borrow() == nil) {
        return []
    }

    return bucketListRef.borrow()!.holdingBucketsList
}