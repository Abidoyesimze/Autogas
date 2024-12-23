// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SafeWallet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => bool) public isAuthorized;
    mapping(address => uint256) public tokenBalances;

    event AuthorizationUpdated(address indexed account, bool authorized);
    event TokensDeposited(address indexed from, address indexed token, uint256 amount);
    event TokensWithdrawn(address indexed to, address indexed token, uint256 amount);
    event EthReceived(address indexed from, uint256 amount);

    constructor() Ownable(msg.sender) {}

    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    function setAuthorized(address account, bool authorized) external onlyOwner {
        isAuthorized[account] = authorized;
        emit AuthorizationUpdated(account, authorized);
    }

    function deposit(address token, uint256 amount) external payable nonReentrant {
        if (token == address(0)) {
            require(msg.value > 0, "No ETH sent");
            emit EthReceived(msg.sender, msg.value);
        } else {
            require(amount > 0, "Amount must be > 0");
            require(token != address(0), "Invalid token address");
            
            uint256 balanceBefore = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            uint256 balanceAfter = IERC20(token).balanceOf(address(this));
            
            uint256 actualAmount = balanceAfter - balanceBefore;
            tokenBalances[token] += actualAmount;
            
            emit TokensDeposited(msg.sender, token, actualAmount);
        }
    }

    function withdraw(
        address token,
        address payable to,
        uint256 amount
    ) external onlyAuthorized nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");

        if (token == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH balance");
            to.transfer(amount);
        } else {
            require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");
            IERC20(token).safeTransfer(to, amount);
            tokenBalances[token] -= amount;
        }

        emit TokensWithdrawn(to, token, amount);
    }

    function getTokenBalance(address token) external view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit EthReceived(msg.sender, msg.value);
    }
}