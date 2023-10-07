import Lending_Borrow from "../../contracts/L&B/L&B.cdc"
import ExampleToken from "../../contracts/standards/ExampleToken.cdc"

transaction(amount: UFix64, bucketId: UInt64?) {

    prepare(account: AuthAccount) {
        var vaultRef = account.borrow<&ExampleToken.Vault>(from: ExampleToken.VaultStoragePath)

        if(vaultRef == nil) {
            account.save(<- ExampleToken.createEmptyVault(), to: ExampleToken.VaultStoragePath)
        }
        let vault = account.borrow<&ExampleToken.Vault>(from: ExampleToken.VaultStoragePath)!

        let bucketList: &Lending_Borrow.bucketList = account.borrow<&Lending_Borrow.bucketList>(from: Lending_Borrow.bucketListStoragePath)!

        if(bucketId != nil) {
            let bucketPath = StoragePath(identifier: Lending_Borrow.liquidityBucketStorageTemplate.concat(bucketId!.toString()))!
            let bucket: @Lending_Borrow.liquidityBucket? <- account.load<@Lending_Borrow.liquidityBucket>(from: bucketPath)!
            let modifiedBucket <- Lending_Borrow.supply(supplyTokenVault: <- vault.withdraw(amount: amount), existingLiquidityBucket: <-bucket, bucketList: bucketList)
            account.save(<- modifiedBucket, to: bucketPath)
        }
        else {
            let modifiedBucket <- Lending_Borrow.supply(supplyTokenVault: <- vault.withdraw(amount: amount), existingLiquidityBucket: nil, bucketList: bucketList)
            let bucketUUID = modifiedBucket.uuid
            account.save(<- modifiedBucket, to: StoragePath(identifier: Lending_Borrow.liquidityBucketStorageTemplate.concat(bucketUUID.toString()))!)
        }
    }
}