import Lending_Borrow from "../../contracts/L&B/L&B.cdc"

pub fun main(): [String] {
    
    let borrowTokensLimit = Lending_Borrow.borrowTokensLimit
    let borrowTokens: [String] = []
    
    borrowTokensLimit.forEachKey(fun (key: String): Bool {
        borrowTokens.append(key)
        return true
    })

    return borrowTokens
}