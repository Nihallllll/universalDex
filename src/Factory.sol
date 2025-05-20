// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29;
import "@openzeppelin/contracts/utils/Create2.sol";
contract Factory {
   mapping (address => mapping(address => address )) public getPair;
   address[] public allPairs;
   

   function createpair(address tokenA ,address tokenB) external returns(address pair) {
         require(tokenA != tokenB);
         require(tokenA != address(0));
         require(tokenB != address(0));
         (address token0 ,address token1 ) = tokenA < tokenB ? (tokenA ,tokenB) : (tokenB, tokenA);
         require(getPair[token0][token1] != address(0));

         bytes memory bytecode = type(Pair).creationCode;
         bytes32 salt = keccak256(abi.encodePacked(token0, token1));
         pair =Create2.deploy(0, salt, bytecode);

         Pair(pair).initialize(token0,token1);

         getPair[token0][token1] = pair;
         getPair[token1][token0] = pair;
         allPairs.push(pair);
   }

   function allPairslength() external view returns(uint){
      return allPairs.length;
   }
}