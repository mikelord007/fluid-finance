import Lending_Borrow from "../../contracts/L&B/L&B.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"
import ExampleToken from "../../contracts/standards/ExampleToken.cdc"

transaction(amount: UFix64, bucketId: UInt64) {

    prepare(account: AuthAccount) {
        
        let vault = account.borrow<&FungibleToken.Vault>(from: ExampleToken.VaultStoragePath)!

        let bucketPath = StoragePath(identifier: Lending_Borrow.liquidityBucketStorageTemplate.concat(bucketId.toString()))!
        let bucket: &Lending_Borrow.liquidityBucket = account.borrow<&Lending_Borrow.liquidityBucket>(from: bucketPath)!
        Lending_Borrow.repay(bucket: bucket, tokenVault: <- vault.withdraw(amount: amount))
        
    }
}