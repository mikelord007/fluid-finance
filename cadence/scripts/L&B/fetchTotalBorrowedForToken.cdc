import Lending_Borrow from "../../contracts/L&B/L&B.cdc"


pub fun main(token: String): UFix64 {

    return Lending_Borrow.totalBorrowed(tokenIdentifier: token)
}