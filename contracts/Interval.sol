// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

interface ITreasury {
    function generateLightspeed() external;
}

interface ILiquidation {
    function convertSpeedToETH() external;
    function distributeETH() external;
}

contract Interval is AutomationCompatibleInterface, Ownable {
    // State variables
    ITreasury public treasury;
    ILiquidation public liquidation;
    uint256 public lastExecutionTimestamp;
    uint256 public constant EXECUTION_INTERVAL = 7 days;
    bool public isPaused;

    // Events
    event IntervalJobExecuted(uint256 timestamp);
    event TreasuryUpdated(address newTreasury);
    event LiquidationUpdated(address newLiquidation);
    event ControllerPaused(bool isPaused);
    event JobExecutionFailed(string reason);

    constructor(
        address _treasury,
        address _liquidation
    ) Ownable(msg.sender) {
        treasury = ITreasury(_treasury);
        liquidation = ILiquidation(_liquidation);
        lastExecutionTimestamp = block.timestamp;
    }

    // Chainlink Automation functions
    function checkUpkeep(bytes calldata) 
        external 
        view 
        override 
        returns (bool upkeepNeeded, bytes memory) 
    {
        upkeepNeeded = !isPaused && 
            ((block.timestamp - lastExecutionTimestamp) >= EXECUTION_INTERVAL);
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata) external override {
        if (isPaused) {
            emit JobExecutionFailed("Controller is paused");
            return;
        }

        if ((block.timestamp - lastExecutionTimestamp) >= EXECUTION_INTERVAL) {
            lastExecutionTimestamp = block.timestamp;
            
            // Execute interval jobs with try-catch
            try treasury.generateLightspeed() {
                // Success
            } catch Error(string memory reason) {
                emit JobExecutionFailed(string(abi.encodePacked("Treasury generation failed: ", reason)));
            }

            try liquidation.convertSpeedToETH() {
                // Success
            } catch Error(string memory reason) {
                emit JobExecutionFailed(string(abi.encodePacked("Speed conversion failed: ", reason)));
            }

            try liquidation.distributeETH() {
                // Success
            } catch Error(string memory reason) {
                emit JobExecutionFailed(string(abi.encodePacked("ETH distribution failed: ", reason)));
            }
            
            emit IntervalJobExecuted(block.timestamp);
        }
    }

    // Admin functions
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = ITreasury(_treasury);
        emit TreasuryUpdated(_treasury);
    }

    function setLiquidation(address _liquidation) external onlyOwner {
        require(_liquidation != address(0), "Invalid liquidation address");
        liquidation = ILiquidation(_liquidation);
        emit LiquidationUpdated(_liquidation);
    }

    function setPaused(bool _isPaused) external onlyOwner {
        isPaused = _isPaused;
        emit ControllerPaused(_isPaused);
    }

    // View functions
    function getTimeUntilNextExecution() external view returns (uint256) {
        uint256 timeSinceLastExecution = block.timestamp - lastExecutionTimestamp;
        if (timeSinceLastExecution >= EXECUTION_INTERVAL) {
            return 0;
        }
        return EXECUTION_INTERVAL - timeSinceLastExecution;
    }

    function getContractAddresses() external view returns (address treasuryAddr, address liquidationAddr) {
        return (address(treasury), address(liquidation));
    }
}