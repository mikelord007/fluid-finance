import Lending_Borrow from "../../contracts/L&B/L&B.cdc"

pub fun main(): [String] {
    
    let supplyTokensLimit = Lending_Borrow.supplyTokensLimit
    let supplyTokens: [String] = []
    
    supplyTokensLimit.forEachKey(fun (key: Type): Bool {
        supplyTokens.append(key.identifier)
        return true
    })

    return supplyTokens
}