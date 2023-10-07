import PayoutToken from "../../contracts/standards/PayoutToken.cdc"

transaction(amount: UFix64) {
    prepare(accnt: AuthAccount) {

        let vault <- PayoutToken.mintTokens(amount: amount)
        let existingVault = accnt.borrow<&PayoutToken.Vault>(from: PayoutToken.VaultStoragePath)
        if(existingVault != nil) {
            existingVault!.deposit(from: <- vault)
        }
        else {
            accnt.save(<- vault, to: PayoutToken.VaultStoragePath)
        }
    }
}