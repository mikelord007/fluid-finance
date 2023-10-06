import Lending_Borrow from "../../contracts/L&B/L&B.cdc"

pub fun main(): [String] {
    
    let borrowTokensLimit = Lending_Borrow.borrowTokensLimit
    let borrowTokens: [String] = []
    
    borrowTokensLimit.forEachKey(fun (key: Type): Bool {
        borrowTokens.append(key.identifier)
        return true
    })

    return borrowTokens
}