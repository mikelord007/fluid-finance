import ExampleToken from "../../contracts/standards/ExampleToken.cdc"

transaction(amount: UFix64) {
    prepare(accnt: AuthAccount) {

        let vault <- ExampleToken.mintTokens(amount: amount)
        let existingVault = accnt.borrow<&ExampleToken.Vault>(from: ExampleToken.VaultStoragePath)
        if(existingVault != nil) {
            existingVault!.deposit(from: <- vault)
        }
        else {
            accnt.save(<- vault, to: ExampleToken.VaultStoragePath)
        }
    }
}