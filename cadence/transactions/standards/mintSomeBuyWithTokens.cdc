import BuyWithToken from "../../contracts/standards/BuyWithToken.cdc"

transaction(amount: UFix64) {
    prepare(accnt: AuthAccount) {

        let vault <- BuyWithToken.mintTokens(amount: amount)
        let existingVault = accnt.borrow<&BuyWithToken.Vault>(from: BuyWithToken.VaultStoragePath)
        if(existingVault != nil) {
            existingVault!.deposit(from: <- vault)
        }
        else {
            accnt.save(<- vault, to: BuyWithToken.VaultStoragePath)
        }
    }
}