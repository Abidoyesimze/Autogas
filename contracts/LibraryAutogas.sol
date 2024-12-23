// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AutogasLib{
     struct StrategicPurchase {
        uint256 totalAmount;
        uint256 initialPurchaseAmount;
        uint256 secondPurchaseAmount;
        uint256 finalPurchaseAmount;
        uint256 initialPurchaseTimestamp;
        bool initialPurchaseComplete;
        bool secondPurchaseComplete;
        bool finalPurchaseComplete;



    }

    enum PaymentType {
        ETH,
        USDC,
        CORE
    }
     
       
    // Events
    event NFTMinted(address indexed to, uint256 quantity, uint256 price, PaymentType paymentType);
    event StrategicPurchaseInitiated(uint256 indexed purchaseId, uint256 totalAmount);
    event StrategicPurchaseCompleted(uint256 indexed purchaseId, uint256 totalTokensReceived);
    event PaymentProcessed(address indexed user, uint256 amount, PaymentType paymentType);
    
    

}