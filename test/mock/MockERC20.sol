pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    // Override transfer functions to allow testing without OpenZeppelin's SafeERC20
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        return super.transfer(recipient, amount);
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        return super.approve(spender, amount);
    }
}
