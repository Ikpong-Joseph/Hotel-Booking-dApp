// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Import the interface containing the HotelSmartContract events
import { HotelSmartContract } from "./HotelSmartContract.sol";

interface IHotelSmartContract {
    function checkRoomAvailability(uint256 roomID, uint256 checkInDate, uint256 checkOutDate) external view returns (bool);
    // function markRoomAsUnavailable(uint256 roomID) external;
    function isBookingConfirmed(address user, uint256 bookingID) external view returns (bool);
    function isBookingCancelled(address guestAdress, uint256 bookingId) external view returns (bool);
    function getBookingCounts(address user) external view returns (uint256);
    function createBooking(uint256 roomID, uint256 checkInDate, uint256 checkOutDate) external;

}


contract PaymentSmartContract {
    address payable public owner;
     // Address of the deployed HotelSmartContract
    address public hotelSmartContractAddress;

    // Event listener for the HotelSmartContract BookingCreated event
    event BookingCreated(address hotelAddress, uint256 bookingID);

    mapping(address => mapping(address => uint256)) public escrowedFunds;
    mapping(address => uint256) public bookingFees;

    event BookingPaymentProcessed(address indexed guestAddress, uint256 totalAmount, uint256 bookingFee);
    event EscrowReleased(address indexed hotelAddress, address indexed guestAddress, uint256 amount);
    event EscrowRefunded(address indexed guestAddress, uint256 amount);

    address payable[] public supportedCurrencies;

    // Address of the HotelSmartContract
    IHotelSmartContract  public HotelSmartContract;

    // Modifier to ensure that only the HotelSmartContract or the owner can call certain functions
    modifier onlyHotelSmartContractOrOwner() {
        require(msg.sender == address(HotelSmartContract) || msg.sender == owner, "Not authorized");
        _;
    }

    // Modifier to ensure that only the owner can call certain functions
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Constructor
    constructor(address payable HotelContractAddress) {
        owner = HotelContractAddress;
        HotelSmartContract = IHotelSmartContract(HotelContractAddress);
    }

    // Function to add a new supported currency
    function addSupportedCurrency(address payable currencyAddress) public onlyHotelSmartContractOrOwner {
        supportedCurrencies.push(currencyAddress);
    }

    // Function to get supported currencies
    function getSupportedCurrencies() public view returns (address payable[] memory) {
        return supportedCurrencies;
    }

   // function setBookingFee(uint256 fee) public onlyHotelSmartContractOrOwner {
       //bookingFees[address(HotelSmartContract)] = fee;
    //}

    function processBookingPayment(address payable guestAddress, uint256 roomID, uint256 checkInDate, uint256 checkOutDate) public payable onlyHotelSmartContractOrOwner {
        // Check room availability in HotelSmartContract
        require(HotelSmartContract.checkRoomAvailability(roomID, checkInDate, checkOutDate), "Room not available");
        
        // Perform payment processing logic
        uint256 roomPrice = room[id][price][address(HotelSmartContract)];
        uint256 bookingFee = bookingFees[address(HotelSmartContract)];
        uint256 duration = checkOutDate - checkInDate;
        uint256 totalCost = roomPrice + bookingFees;
        require(msg.value == totalCost, "Insufficient payment");

        uint256 escrowAmount = roomPrice - bookingFee;

        // Mark room as unavailable in HotelSmartContract
        // HotelSmartContract.markRoomAsUnavailable(roomID);
        emit BookingPaymentProcessed(guestAddress, msg.value, bookingFee);
    }

     // Event listener for HotelSmartContract BookingCreated event
    function onHotelBookingCreated(address guestAddress, uint256 roomID, uint256 checkInDate, uint256 checkOutDate) external {
        // Trigger the processBookingPayment function
        processBookingPayment(payable(guestAddress), roomID, checkInDate, checkOutDate);
    }

    function releaseEscrow(address payable guestAddress, uint256 bookingID) public onlyHotelSmartContractOrOwner {
        uint256 amount = escrowedFunds[address(HotelSmartContract)][guestAddress];
        require(amount > 0, "No funds in escrow for this guest");

        // Check if the booking has been confirmed
        require(HotelSmartContract.isBookingConfirmed(guestAddress, bookingID), "Booking not confirmed");

        // Transfer funds from escrow to the hotel
        escrowedFunds[address(HotelSmartContract)][guestAddress] = 0;
        payable(address(HotelSmartContract)).transfer(amount);

        // Emit event indicating successful escrow release
        emit EscrowReleased(address(HotelSmartContract), guestAddress, amount);
    }


   function refundEscrow(address payable guestAddress, uint256 roomID, uint256 checkInDate) public onlyHotelSmartContractOrOwner {
        uint256 totalAmount = escrowedFunds[address(HotelSmartContract)][guestAddress];
        require(totalAmount > 0, "No funds in escrow for this guest");

        // Check if the booking is not confirmed or has been canceled
        uint256 bookingID = IHotelSmartContract(HotelSmartContract).getBookingCounts(guestAddress);
        require(!HotelSmartContract.isBookingConfirmed(guestAddress, bookingID) || HotelSmartContract.isBookingCancelled(guestAddress, bookingID), "Booking is confirmed or not canceled");

        // Check if 7 days have passed since the check-in date
        require(block.timestamp >= checkInDate + 7 days, "Refund not yet available");

        // Get the booking fee
        uint256 bookingFee = bookingFees[address(HotelSmartContract)];

        uint256 roomPrice = room[id][price][address(HotelSmartContract)];
    

        // Calculate the remaining escrow amount (excluding booking fee)
        uint256 escrowAmount = roomPrice - bookingFee;

        // Refund only the remaining escrow amount to the guest
        escrowedFunds[address(HotelSmartContract)][guestAddress] = 0;
        guestAddress.transfer(escrowAmount);

        // Emit event indicating successful escrow refund
        emit EscrowRefunded(guestAddress, escrowAmount);
    }

}
