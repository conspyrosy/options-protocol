/**
Mock USDC
*/
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * Mock USDC Token
 */
contract USDC is ERC20 {
    constructor() ERC20("USDC", "USDC") public {
        _mint(msg.sender, 1000000000000000000000000); // 1,000,000 USDC
    }
}
