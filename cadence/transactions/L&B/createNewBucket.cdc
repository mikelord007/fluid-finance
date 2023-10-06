import Lending_Borrow from "../../contracts/L&B/L&B.cdc"

transaction() {
    prepare(accnt: AuthAccount) {

        var bucketList: &Lending_Borrow.bucketList? = accnt.borrow<&Lending_Borrow.bucketList>(from: Lending_Borrow.bucketListStoragePath)
        
        if(bucketList == nil) {
            let newBucketList <- Lending_Borrow.createBucketList()
            accnt.save(<- newBucketList, to: Lending_Borrow.bucketListStoragePath)
            accnt.link<&Lending_Borrow.bucketList>(Lending_Borrow.bucketListPublicPath, target: Lending_Borrow.bucketListStoragePath)
            bucketList = accnt.getCapability<&Lending_Borrow.bucketList>(Lending_Borrow.bucketListPublicPath).borrow()!
        }

        let newBucket <- Lending_Borrow.createEmptyBucket(bucketList: bucketList!)
        let bucketUUID = newBucket.uuid
        accnt.save(<- newBucket, to: StoragePath(identifier: Lending_Borrow.liquidityBucketStorageTemplate.concat(bucketUUID.toString()))!)
    }
}