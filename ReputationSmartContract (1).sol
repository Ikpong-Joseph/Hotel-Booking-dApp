// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHotelSmartContract {
    function getBookingCounts(address user) external view returns (uint256);
}

contract ReputationSmartContract {

    // Contract owner address
    address payable public owner;

    // Address of the HotelSmartContract
    IHotelSmartContract  public HotelSmartContract;

    // Payment smart contract address (optional)
    address payable public paymentContract;

    // Mapping for user reputation scores
    mapping(address => uint256) public reputationScore;

    // Mapping for storing reviewers
    mapping(address => address[]) public feedbackGivers;

    // Mapping for storing feedback details
    mapping(address => mapping(address => Feedback)) public feedback;

    // Events
    event ReviewSubmitted(address reviewer, address user, uint256 rating, string comment);
    event IncentiveClaimed(address userAddress, uint256 amount);

     // Incentive related variables
    uint256 public incentiveAmount;
    mapping(address => bool) public hasClaimedIncentive;
    uint256 public withdrawalPeriod; // Time period (in seconds) during which reviewers can withdraw incentives
    mapping(address => uint256) public incentiveWithdrawalDeadline;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }


    // Constructor
    constructor(address payable paymentContractAddress, uint256 _incentiveAmount, uint256 _withdrawalPeriod, address payable HotelContractAddress) {
        owner = payable(msg.sender);
        paymentContract = payable (paymentContractAddress);
        incentiveAmount = _incentiveAmount;
        withdrawalPeriod = _withdrawalPeriod;
        HotelSmartContract = IHotelSmartContract(HotelContractAddress);
    }


    // Function to submit review with rating and comment
    function submitReview(address userAddress, uint256 rating, string memory comment) public {
        require(msg.sender != userAddress, "Cannot review yourself");
        require(!isReviewer(userAddress, msg.sender), "Already reviewed this user");
        require(rating > 0 && rating <= 5, "Rating must be between 1 and 5");

        // Check if the user has a confirmed booking
        require(hasConfirmedBooking(userAddress), "User must have a confirmed booking to submit a review");

        // Update user reputation score
        reputationScore[userAddress] += rating;

        // Store feedback details
        feedback[userAddress][msg.sender] = Feedback(rating, comment);

        // Add reviewer address to list
        feedbackGivers[userAddress].push(msg.sender);

       // Set the incentive withdrawal deadline
        incentiveWithdrawalDeadline[msg.sender] = block.timestamp + withdrawalPeriod;

        emit ReviewSubmitted(msg.sender, userAddress, rating, comment);
    }

    // Function to check if the user has a confirmed booking
    function hasConfirmedBooking(address userAddress) internal view returns (bool) {
        // Use HotelSmartContract's function to get the user's confirmed bookings
        uint256 confirmedBookingsCount = HotelSmartContract.getBookingCounts(userAddress);
        return confirmedBookingsCount > 0;

    }
     // Function to withdraw incentives (within the withdrawal period)
    function withdrawIncentive() public {
        require(incentiveWithdrawalDeadline[msg.sender] > 0, "No incentives to withdraw");
        require(block.timestamp <= incentiveWithdrawalDeadline[msg.sender], "Withdrawal period has ended");

        // Transfer incentive
        paymentContract.transfer(incentiveAmount);
        
        // Mark the incentive as claimed
        incentiveWithdrawalDeadline[msg.sender] = 0;

        emit IncentiveClaimed(msg.sender, incentiveAmount);
    }

    // Function to set the incentive amount (only callable by the owner)
    function setIncentiveAmount(uint256 amount) public onlyOwner {
        incentiveAmount = amount;
    }

    // Function to set the withdrawal period (only callable by the owner)
    function setWithdrawalPeriod(uint256 period) public onlyOwner {
        withdrawalPeriod = period;
    }


    // Function to get user reputation score
    function getReputationScore(address userAddress) public view returns (uint256) {
        return reputationScore[userAddress];
    }


    // Function to get all feedback details for a user
    function getFeedbackDetails(address userAddress) public view returns (Feedback[] memory) {
        Feedback[] memory userFeedback = new Feedback[](feedbackGivers[userAddress].length);
        for (uint256 i = 0; i < feedbackGivers[userAddress].length; i++) {
            userFeedback[i] = feedback[userAddress][feedbackGivers[userAddress][i]];
        }
        return userFeedback;
    }

    // Function to get list of reviewers for a user
    function getReviewers(address userAddress) public view returns (address[] memory) {
        return feedbackGivers[userAddress];
    }

    // Function for contract owner to update user reputation score (optional)
    function updateReputationScore(address userAddress, uint256 newScore) public onlyOwner {
        // require(msg.sender == owner, "Only owner can update reputation scores");
        reputationScore[userAddress] = newScore;
    }

    // Helper function to check if a user has already reviewed another user
    function isReviewer(address userAddress, address reviewer) private view returns (bool) {
        for (uint256 i = 0; i < feedbackGivers[userAddress].length; i++) {
            if (feedbackGivers[userAddress][i] == reviewer) {
                return true;
            }
        }
        return false;
    }

    // Optional: Implement logic for weighted ratings based on reviewer reputation

    // Optional: Implement dispute resolution mechanisms for challenging unfair reviews

    // Optional: Implement time-based decay of reviews to reflect evolving user behavior

    // Optional: Integrate secure random number generator for specific functionalities
}

// Feedback structure
struct Feedback {
    uint256 rating;
    string comment;
}

