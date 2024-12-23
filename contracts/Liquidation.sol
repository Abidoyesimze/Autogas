// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function WETH() external pure returns (address);
}

contract LiquidationContract is Ownable, ReentrancyGuard {
    // Structs
    struct Holder {
        address walletAddress;
        uint256 sharePercentage;
    }

    // State variables
    IUniswapV2Router02 public uniswapRouter;
    IERC20 public speedToken;
    address public treasury;
    Holder[] public holders;
    uint256 public lastUpdateTimestamp;
    uint256 public constant UPDATE_INTERVAL = 7 days;
    uint256 public constant MINIMUM_LIQUIDATION_AMOUNT = 1e18; // 1 Speed token
    
    // Events
    event AirdropListUpdated(uint256 holderCount);
    event SpeedLiquidated(uint256 speedAmount, uint256 ethReceived);
    event EthDistributed(uint256 totalAmount);
    event HolderAdded(address indexed holder, uint256 sharePercentage);
    event HolderRemoved(address indexed holder);

    constructor(
        address _uniswapRouter,
        address _speedToken,
        address _treasury
    ) Ownable(msg.sender) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        speedToken = IERC20(_speedToken);
        treasury = _treasury;
        lastUpdateTimestamp = block.timestamp;
    }

    // Airdrop list management
    function updateAirdropList(
        address[] calldata _holders,
        uint256[] calldata _shares
    ) external {
        require(msg.sender == treasury || msg.sender == owner(), "Unauthorized");
        require(_holders.length == _shares.length, "Array length mismatch");
        require(_holders.length > 0, "Empty holder list");
        
        delete holders;
        uint256 totalShares = 0;
        
        for(uint256 i = 0; i < _holders.length; i++) {
            require(_holders[i] != address(0), "Invalid holder address");
            require(_shares[i] > 0, "Invalid share percentage");
            
            totalShares += _shares[i];
            holders.push(Holder({
                walletAddress: _holders[i],
                sharePercentage: _shares[i]
            }));
        }
        
        require(totalShares == 100, "Shares must total 100");
        lastUpdateTimestamp = block.timestamp;
        emit AirdropListUpdated(holders.length);
    }

    // Liquidation functions
    function convertSpeedToETH() external nonReentrant {
        uint256 speedBalance = speedToken.balanceOf(address(this));
        require(speedBalance >= MINIMUM_LIQUIDATION_AMOUNT, "Insufficient Speed balance");
        
        // Approve Uniswap router
        speedToken.approve(address(uniswapRouter), speedBalance);
        
        // Setup path for Speed -> WETH
        address[] memory path = new address[](2);
        path[0] = address(speedToken);
        path[1] = uniswapRouter.WETH();
        
        // Execute swap
        uint256[] memory amounts = uniswapRouter.swapExactTokensForETH(
            speedBalance,
            0, // Accept any amount of ETH
            path,
            address(this),
            block.timestamp + 300
        );
        
        emit SpeedLiquidated(speedBalance, amounts[1]);
        
        // Automatically distribute ETH
        distributeETH();
    }

    // Distribution function
    function distributeETH() public nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to distribute");
        require(holders.length > 0, "No holders configured");
        
        for(uint256 i = 0; i < holders.length; i++) {
            uint256 share = (balance * holders[i].sharePercentage) / 100;
            if(share > 0) {
                payable(holders[i].walletAddress).transfer(share);
            }
        }
        
        emit EthDistributed(balance);
    }

    // View functions
    function getHolders() external view returns (Holder[] memory) {
        return holders;
    }

    function getHolderCount() external view returns (uint256) {
        return holders.length;
    }

    function getTimeUntilNextUpdate() external view returns (uint256) {
        uint256 timeSinceLastUpdate = block.timestamp - lastUpdateTimestamp;
        if (timeSinceLastUpdate >= UPDATE_INTERVAL) {
            return 0;
        }
        return UPDATE_INTERVAL - timeSinceLastUpdate;
    }

    // Emergency functions
    function emergencyWithdraw(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(address(this).balance);
        } else {
            IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
        }
    }

    // Receive function for ETH
    receive() external payable {}
}