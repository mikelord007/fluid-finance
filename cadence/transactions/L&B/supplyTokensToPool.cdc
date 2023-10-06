import Lending_Borrow from "../../contracts/L&B/L&B.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"
import ExampleToken from "../../contracts/standards/ExampleToken.cdc"

transaction(tokenContractName: String, tokenAddress: Address, amount: UFix64, bucketId: UInt64?) {

    prepare(account: AuthAccount) {
        let tokenContract = getAccount(tokenAddress).contracts.borrow<&ExampleToken>(name: tokenContractName)
        let vault = account.borrow<&FungibleToken.Vault>(from: tokenContract!.VaultStoragePath)!

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