// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISpeedToken {
    function mint(address to, uint256 amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract EnhancedTreasury is Ownable, ReentrancyGuard {
    ISpeedToken public speedToken;
    IERC20 public coreToken;
    uint256 public constant GENERATION_RATE = 100; 
    uint256 public lastGenerationTimestamp;
    uint256 public constant GENERATION_INTERVAL = 7 days;
    address public liquidationContract;

    event LightspeedGenerated(uint256 amount);
    event TransferredToLiquidation(uint256 amount);
    event CoreTokensReceived(address from, uint256 amount);

    constructor(
        address _speedToken,
        address _coreToken
    ) Ownable(msg.sender) {
        speedToken = ISpeedToken(_speedToken);
        coreToken = IERC20(_coreToken);
        lastGenerationTimestamp = block.timestamp;
    }

    function setLiquidationContract(address _liquidation) external onlyOwner {
        require(_liquidation != address(0), "Invalid liquidation address");
        liquidationContract = _liquidation;
    }

    // Add this function to explicitly receive CORE tokens
    function receiveCoreTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(coreToken.transferFrom(msg.sender, address(this), amount), 
                "Transfer failed");
        
        emit CoreTokensReceived(msg.sender, amount);
    }

    function generateLightspeed() external nonReentrant {
        require(block.timestamp >= lastGenerationTimestamp + GENERATION_INTERVAL, 
                "Generation interval not met");
        require(liquidationContract != address(0), 
                "Liquidation contract not set");
        
        uint256 coreBalance = coreToken.balanceOf(address(this));
        require(coreBalance > 0, "No CORE tokens available");
        
        uint256 speedToGenerate = coreBalance * GENERATION_RATE;
        
        speedToken.mint(address(this), speedToGenerate);
        lastGenerationTimestamp = block.timestamp;
        
        emit LightspeedGenerated(speedToGenerate);
        
        // Send to liquidation contract
        require(speedToken.transfer(liquidationContract, speedToGenerate),
                "Transfer to liquidation failed");
        emit TransferredToLiquidation(speedToGenerate);
    }

    // View function to check next generation time
    function getTimeUntilNextGeneration() external view returns (uint256) {
        if (block.timestamp >= lastGenerationTimestamp + GENERATION_INTERVAL) {
            return 0;
        }
        return lastGenerationTimestamp + GENERATION_INTERVAL - block.timestamp;
    }

    // Emergency function
    function emergencyWithdraw(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(address(this).balance);
        } else {
            IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
        }
    }
}