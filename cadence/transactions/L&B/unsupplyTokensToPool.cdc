import Lending_Borrow from "../../contracts/L&B/L&B.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"
import ExampleToken from "../../contracts/standards/ExampleToken.cdc"

transaction(amount: UFix64, bucketId: UInt64) {

    prepare(account: AuthAccount) {
        
        let dummyVault <- ExampleToken.createEmptyVault()
        let tokenIdentifier = dummyVault.getType().identifier
        destroy dummyVault

        let bucketList: &Lending_Borrow.bucketList = account.borrow<&Lending_Borrow.bucketList>(from: Lending_Borrow.bucketListStoragePath)!

        let bucketPath = StoragePath(identifier: Lending_Borrow.liquidityBucketStorageTemplate.concat(bucketId.toString()))!
        let bucket: &Lending_Borrow.liquidityBucket = account.borrow<&Lending_Borrow.liquidityBucket>(from: bucketPath)!
        let returnVault <- Lending_Borrow.unsupply(bucket: bucket, tokenIdentifier: tokenIdentifier, amount: amount)
        let vault = account.borrow<&FungibleToken.Vault>(from: ExampleToken.VaultStoragePath)!
        vault.deposit(from: <- returnVault)
    }
}