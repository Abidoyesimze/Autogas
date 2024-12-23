// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AutogasNft.sol";
import "./ReferralSystem.sol";
import "./IAutogasNft.sol";
import "contracts/LibraryAutogas.sol";

contract Autogas is AutogasNft, ReferralSystem {
    using AutogasLib for uint256;
    AutogasLib.StrategicPurchase internal Purchase;
     uint256 public strategicPurchaseCounter;

        mapping(uint256 => AutogasLib.StrategicPurchase) strategicPurchases;
   

    constructor(
        string memory uri_,
        address _ethPriceFeed,
        address _usdcPriceFeed,
        address _coreToken,
        address _speedToken,
        address _uniswapRouter,
        address _v3Quoter,
        address _treasury,
        address _liquidation,
        address _teamWallet
    ) AutogasNft(
        uri_,
        _ethPriceFeed,
        _usdcPriceFeed,
        _coreToken,
        _speedToken,
        _uniswapRouter,
        _v3Quoter,
        _treasury,
        _liquidation,
        _teamWallet
    ) {}

    function mintNFT(
        uint256 quantity,
        AutogasLib.PaymentType paymentType,
        string memory referralCode
    ) external payable override nonReentrant {
        require(quantity > 0, "Invalid quantity");
        
        // Calculate price and validate payment
        uint256 totalPrice = _validatePrice(quantity, paymentType);
        address referrer = _validateReferralCode(referralCode, msg.sender);
        
        if (referrer != address(0)) {
            totalPrice = totalPrice * (100 - REFERRAL_DISCOUNT_PERCENTAGE) / 100;
        }

        if (quantity >= BULK_DISCOUNT_THRESHOLD) {
            totalPrice = totalPrice * (100 - BULK_DISCOUNT_PERCENTAGE) / 100;
        }

        // Process payment based on type
        if (paymentType == AutogasLib.PaymentType.ETH) {
            require(msg.value >= totalPrice, "Insufficient ETH");
            _processETHPayment(totalPrice, quantity, referrer);
            // uint256 teamFee = (totalPrice * TEAM_FEE_PERCENTAGE) / 100;
            //      payable(teamWallet).transfer(teamFee);

            //      uint256 remainingFunds = totalPrice - teamFee;
            //      _purchaseCoreTokens(remainingFunds);
            
            // Refund excess ETH
            if (msg.value > totalPrice) {
                payable(msg.sender).transfer(msg.value - totalPrice);
            }
        } 
        else if (paymentType == AutogasLib.PaymentType.USDC) {
            require(msg.value == 0, "ETH not needed");
            _processUSDCPayment(totalPrice, quantity, referrer);
        } 
        else {
            require(msg.value == 0, "ETH not needed");
            _processCOREPayment(totalPrice, quantity, referrer);
        }

        // Mint NFT
        _mint(msg.sender, NFT_ID, quantity, "");
        totalMinted += quantity;

        emit AutogasLib.NFTMinted(msg.sender, quantity, totalPrice, paymentType);
    }

    function calculateMintPrice(
        uint256 quantity, 
        string memory referralCode
    ) external view override returns (uint256) {
        uint256 baseTotal = BASE_PRICE * quantity;
        
        if (quantity >= BULK_DISCOUNT_THRESHOLD) {
            return baseTotal * (100 - BULK_DISCOUNT_PERCENTAGE) / 100;
        }
        
        address referrer = referralCodeToAddress[referralCode];
        if (referrer != address(0) && referrer != msg.sender) {
            return baseTotal * (100 - REFERRAL_DISCOUNT_PERCENTAGE) / 100;
        }
        
        return baseTotal;
    }

    // Strategic purchase functions
    function initiateStrategicPurchase(uint256 totalAmount) external onlyOwner {
        require(totalAmount > 0, "Invalid amount");
        
        uint256 initialAmount = (totalAmount * 60) / 100;
        uint256 secondAmount = (totalAmount * 30) / 100;
        uint256 finalAmount = totalAmount - initialAmount - secondAmount;
        
         strategicPurchases[strategicPurchaseCounter] = AutogasLib.StrategicPurchase({
            totalAmount: totalAmount,
            initialPurchaseAmount: initialAmount,
            secondPurchaseAmount: secondAmount,
            finalPurchaseAmount: finalAmount,
            initialPurchaseTimestamp: block.timestamp,
            initialPurchaseComplete: false,
            secondPurchaseComplete: false,
            finalPurchaseComplete: false
        });
        
        emit AutogasLib.StrategicPurchaseInitiated(strategicPurchaseCounter++, totalAmount);
    }

    function executeStrategicPurchase(uint256 purchaseId) external onlyOwner {
        AutogasLib.StrategicPurchase storage purchase = Purchase[purchaseId];
        require(!purchase.finalPurchaseComplete, "Purchase completed");
        
        if (!purchase.initialPurchaseComplete) {
            _executePurchaseStage(purchaseId, purchase.initialPurchaseAmount);
            purchase.initialPurchaseComplete = true;
        }
        else if (!purchase.secondPurchaseComplete && 
                 block.timestamp >= purchase.initialPurchaseTimestamp + 5 minutes) {
            _executePurchaseStage(purchaseId, purchase.secondPurchaseAmount);
            purchase.secondPurchaseComplete = true;
        }
        else if (block.timestamp >= purchase.initialPurchaseTimestamp + 10 minutes) {
            _executePurchaseStage(purchaseId, purchase.finalPurchaseAmount);
            purchase.finalPurchaseComplete = true;
            
            // Transfer all accumulated tokens to treasury
            uint256 totalTokens = coreToken.balanceOf(address(this));
            coreToken.approve(address(treasury), totalTokens);
            treasury.receiveCoreTokens(totalTokens);
            
            emit AutogasLib.StrategicPurchaseCompleted(purchaseId, totalTokens);
        }
    }

    // Internal payment processing functions
    function _processETHPayment(
        uint256 amount,
        uint256 quantity,
        address referrer
    ) internal {
        uint256 teamFee = (amount * TEAM_FEE_PERCENTAGE) / 100;
        payable(teamWallet).transfer(teamFee);

        if (referrer != address(0)) {
            uint256 referralFee = processReferralReward(referrer, amount);
            amount -= referralFee;
        }

        // Convert remaining ETH to CORE and send to treasury
        uint256 remaining = amount - teamFee;
        _convertETHToCORE(remaining);
        
        emit AutogasLib.PaymentProcessed(msg.sender, amount, AutogasLib.PaymentType.ETH);
    }

    function _processUSDCPayment(
        uint256 amount,
        uint256 quantity,
        address referrer
    ) internal {
        require(usdcToken.transferFrom(msg.sender, address(this), amount), "USDC transfer failed");
        
        uint256 teamFee = (amount * TEAM_FEE_PERCENTAGE) / 100;
        require(usdcToken.transfer(teamWallet, teamFee), "Team fee transfer failed");  // Send to team wallet

        if (referrer != address(0)) {
            uint256 referralFee = processReferralReward(referrer, amount);
            amount -= referralFee;
        }

        // Convert remaining USDC to CORE and send to treasury
        uint256 remaining = amount - teamFee;
        _convertUSDCToCORE(remaining);
        
        emit AutogasLib.PaymentProcessed(msg.sender, amount, AutogasLib.PaymentType.USDC);
    }

    function _processCOREPayment(
        uint256 amount,
        uint256 quantity,
        address referrer
    ) internal {
        require(coreToken.transferFrom(msg.sender, address(this), amount), "CORE transfer failed");
        
        uint256 teamFee = (amount * TEAM_FEE_PERCENTAGE) / 100;
        require(coreToken.transfer(teamWallet, teamFee), "Team fee transfer failed");  // Send to team wallet

        if (referrer != address(0)) {
            uint256 referralFee = processReferralReward(referrer, amount);
            amount -= referralFee;
        }

        // Send remaining CORE directly to treasury
        uint256 remaining = amount - teamFee;
        coreToken.approve(address(treasury), remaining);
        treasury.receiveCoreTokens(remaining);
        
        emit AutogasLib.PaymentProcessed(msg.sender, amount, AutogasLib.PaymentType.CORE);
    }

    // Internal conversion functions
    function _convertETHToCORE(uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(coreToken);
        
        uniswapRouter.swapExactETHForTokens{value: amount}(
            0, // Accept any amount
            path,
            address(treasury),
            block.timestamp + 300
        );
    }

    function _convertUSDCToCORE(uint256 amount) internal {
        usdcToken.approve(address(uniswapRouter), amount);
        
        address[] memory path = new address[](3);
        path[0] = address(usdcToken);
        path[1] = WETH;
        path[2] = address(coreToken);
        
        uniswapRouter.swapExactTokensForTokens(
            amount,
            0, // Accept any amount
            path,
            address(treasury),
            block.timestamp + 300
        );
    }

    function _executePurchaseStage(uint256 purchaseId, uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(coreToken);
        
        uniswapRouter.swapExactETHForTokens{value: amount}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );
    }

    
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    receive() external payable {}
}