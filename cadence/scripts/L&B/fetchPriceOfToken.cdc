import Lending_Borrow from "../../contracts/L&B/L&B.cdc"


pub fun main(token: Type): {String: UFix64} {

    let borrowedTokens: {String: UFix64} = {}
    
    Lending_Borrow.fetchPriceFromOracle(type: token)

    return borrowedTokens
}