import StakeToken from "../../contracts/standards/StakeToken.cdc"

transaction(amount: UFix64) {
    prepare(accnt: AuthAccount) {

        let vault <- StakeToken.mintTokens(amount: amount)
        let existingVault = accnt.borrow<&StakeToken.Vault>(from: StakeToken.VaultStoragePath)
        if(existingVault != nil) {
            existingVault!.deposit(from: <- vault)
        }
        else {
            accnt.save(<- vault, to: StakeToken.VaultStoragePath)
        }
    }
}