import ExampleToken from "../../contracts/standards/ExampleToken.cdc"

transaction(tokenContractName: String, tokenAddress: Address, amount: UFix64) {
    prepare(accnt: AuthAccount) {
        let tokenContract = getAccount(tokenAddress).contracts.borrow<&ExampleToken>(name: tokenContractName)!

        let vault <- tokenContract.mintTokens(amount: amount)
        let existingVault = accnt.borrow<&ExampleToken.Vault>(from: tokenContract.VaultStoragePath)
        if(existingVault != nil) {
            existingVault!.deposit(from: <- vault)
        }
        else {
            accnt.save(<- vault, to: tokenContract.VaultStoragePath)
        }
    }
}