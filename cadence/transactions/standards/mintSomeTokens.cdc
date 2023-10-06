import BuyWithToken from "../../contracts/standards/BuyWithToken.cdc"

transaction(tokenAddress: Address, tokenContractName: String, amount: UFix64) {
    prepare(accnt: AuthAccount) {
        let tokenContract = getAccount(tokenAddress).contracts.borrow<&BuyWithToken>(name: tokenContractName)!

        let vault <- tokenContract.mintTokens(amount: amount)
        let existingVault = accnt.borrow<&BuyWithToken.Vault>(from: BuyWithToken.VaultStoragePath)
        if(existingVault != nil) {
            existingVault!.deposit(from: <- vault)
        }
        else {
            accnt.save(<- vault, to: BuyWithToken.VaultStoragePath)
        }
    }
}