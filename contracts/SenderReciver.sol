// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

contract Transfer {
    event PaymentProcessed(
        address indexed sender,
        address indexed receiver,
        uint receiverAmount,
        uint ownerAmount,
        string message
    );

    event EscrowCreated(
        uint indexed dealId,
        address indexed sender,
        address indexed receiver,
        uint amount,
        string message
    );

    event EscrowReleased(uint indexed dealId, address indexed to, uint amount);

    event EscrowCancelled(
        uint indexed dealId,
        address indexed sender,
        uint amount
    );

    event DealLocked(uint indexed dealId);
    event RatingSubmitted(
        address indexed from,
        address indexed to,
        uint rating
    );

    address public owner;
    uint public feePercent = 1;

    enum DealStatus {
        Pending,
        Released,
        Cancelled
    }

    struct EscrowDeal {
        address sender;
        address payable receiver;
        uint amount;
        string message;
        DealStatus status;
        uint createdAt;
        bool isLocked;
    }

    mapping(uint => EscrowDeal) public deals;
    uint public dealCount;

    mapping(address => uint[]) public userDeals;
    mapping(address => uint[]) public ratingsGiven;
    mapping(address => uint[]) public ratingsReceived;

    uint constant TIMEOUT = 1 days;
    uint constant ARBITRATION_PERIOD = 4 days;

    constructor() {
        owner = msg.sender;
    }

    function setFeePercent(uint newFee) external {
        require(msg.sender == owner, "Only owner can set fee");
        require(newFee <= 10, "Fee too high");
        feePercent = newFee;
    }

    function sendTo(address payable receiver, string calldata message)
        external
        payable
    {
        require(msg.value > 0, "Send some ETH");
        require(receiver != address(0), "Receiver address?");

        (uint ownerShare, uint receiverShare) = calculateShares(msg.value);

        (bool sentReceiver, ) = receiver.call{value: receiverShare}("");
        require(sentReceiver, "ETH transfer to receiver failed");

        (bool sentOwner, ) = payable(owner).call{value: ownerShare}("");
        require(sentOwner, "ETH transfer to owner failed");

        emit PaymentProcessed(
            msg.sender,
            receiver,
            receiverShare,
            ownerShare,
            message
        );
    }

    function createDeal(address payable receiver, string calldata message)
        external
        payable
    {
        require(msg.value > 0, "Send some ETH");
        require(receiver != address(0), "Invalid receiver");

        deals[dealCount] = EscrowDeal({
            sender: msg.sender,
            receiver: receiver,
            amount: msg.value,
            message: message,
            status: DealStatus.Pending,
            createdAt: block.timestamp,
            isLocked: false
        });

        userDeals[msg.sender].push(dealCount);
        userDeals[receiver].push(dealCount);

        emit EscrowCreated(dealCount, msg.sender, receiver, msg.value, message);
        dealCount++;
    }

    function releaseDeal(uint dealId) external {
        EscrowDeal storage deal = deals[dealId];
        require(msg.sender == deal.sender, "Only sender can release");
        require(deal.status == DealStatus.Pending, "Not pending");
        require(!deal.isLocked, "Deal is locked");

        deal.status = DealStatus.Released;

        (bool sent, ) = deal.receiver.call{value: deal.amount}("");
        require(sent, "Transfer to receiver failed");

        emit EscrowReleased(dealId, deal.receiver, deal.amount);
    }

    function cancelDeal(uint dealId) external {
        EscrowDeal storage deal = deals[dealId];
        require(msg.sender == owner, "Only owner can cancel");
        require(deal.status == DealStatus.Pending, "Already processed");
        require(!deal.isLocked, "Deal is locked");

        deal.status = DealStatus.Cancelled;

        (bool sent, ) = payable(deal.sender).call{value: deal.amount}("");
        require(sent, "Refund failed");

        emit EscrowCancelled(dealId, deal.sender, deal.amount);
    }

    function lockDeal(uint dealId) public {
        EscrowDeal storage deal = deals[dealId];
        require(deal.status == DealStatus.Pending, "Deal not pending");
        require(!deal.isLocked, "Already locked");
        require(
            block.timestamp >= deal.createdAt + TIMEOUT,
            "Too early to lock"
        );

        deal.isLocked = true;
        emit DealLocked(dealId);
    }

    function autoLock(uint dealId) external {
        lockDeal(dealId);
    }

    function arbitrate(uint dealId, bool releaseToSeller) external {
        EscrowDeal storage deal = deals[dealId];
        require(msg.sender == owner, "Only owner can arbitrate");
        require(deal.status == DealStatus.Pending, "Deal not pending");
        require(deal.isLocked, "Deal not locked");
        require(
            block.timestamp <= deal.createdAt + TIMEOUT + ARBITRATION_PERIOD,
            "Arbitration period expired"
        );

        deal.status = DealStatus.Released;

        address payable recipient = releaseToSeller
            ? deal.receiver
            : payable(deal.sender);
        (bool sent, ) = recipient.call{value: deal.amount}("");
        require(sent, "Transfer failed");

        emit EscrowReleased(dealId, recipient, deal.amount);
    }

    function submitRating(address to, uint rating) external {
        require(rating <= 5, "Max rating is 5");
        ratingsGiven[msg.sender].push(rating);
        ratingsReceived[to].push(rating);

        emit RatingSubmitted(msg.sender, to, rating);
    }

    function calculateShares(uint totalAmount)
        internal
        view
        returns (uint ownerShare, uint receiverShare)
    {
        ownerShare = (totalAmount * feePercent) / 100;
        receiverShare = totalAmount - ownerShare;
        return (ownerShare, receiverShare);
    }

    receive() external payable {
        revert("Direct payments not allowed. Use sendTo.");
    }

    fallback() external payable {
        revert("Function does not exist");
    }
}
