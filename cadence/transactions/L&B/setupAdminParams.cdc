import Lending_Borrow from "../../contracts/L&B/L&B.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"
import ExampleToken from "../../contracts/standards/ExampleToken.cdc"

transaction() {
    prepare(adminAccount: AuthAccount) {

        let vaultInit <- ExampleToken.mintTokens(amount: 10000000000.00)
        let tokenTypeIdentifier = vaultInit.getType().identifier
        adminAccount.save(<- vaultInit, to: ExampleToken.VaultStoragePath)

        let bucketList <- Lending_Borrow.createBucketList()
        adminAccount.save(<- bucketList, to: Lending_Borrow.bucketListStoragePath)
        adminAccount.link<&Lending_Borrow.bucketList>(Lending_Borrow.bucketListPublicPath, target: Lending_Borrow.bucketListStoragePath)
        let bucketListRef = adminAccount.getCapability<&Lending_Borrow.bucketList>(Lending_Borrow.bucketListPublicPath).borrow()!

        let adminResource = adminAccount.borrow<&Lending_Borrow.Administrator>(from: Lending_Borrow.AdminResourceStoragePath)

        adminResource!.modifyBorrowLimitPerBucket(newLimit: 80.00)
        adminResource!.modifySupplyTokensLimit(supplyToken: tokenTypeIdentifier, limit: 1000000000.0)
        adminResource!.modifyBorrowTokensLimit(borrowToken: tokenTypeIdentifier, limit: 70.0)
        let dump <- adminResource!.initTokenVault(tokenIdentifier: tokenTypeIdentifier, vault: <- ExampleToken.createEmptyVault())
        destroy dump
        
        let vault = adminAccount.borrow<&FungibleToken.Vault>(from: ExampleToken.VaultStoragePath)

        let bucket: @Lending_Borrow.liquidityBucket <- Lending_Borrow.supply(supplyTokenVault: <- vault!.withdraw(amount: 1000000.00), existingLiquidityBucket: nil, bucketList: bucketListRef)
        let bucketUUID = bucket.uuid.toString()
        adminAccount.save(<- bucket, to: StoragePath(identifier: Lending_Borrow.liquidityBucketStorageTemplate.concat(bucketUUID))!)
    }
}