// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { HotelSmartContract } from "./HotelSmartContract.sol";
import { PaymentSmartContract } from "./PSC(V1.3).sol";


interface IHotelSmartContract {
    function checkRoomAvailability(uint256 roomID, uint256 checkInDate, uint256 checkOutDate) external view returns (bool);
    // function markRoomAsUnavailable(uint256 roomID) external;
    function isBookingConfirmed(address user, uint256 bookingID) external view returns (bool);
    function isBookingCancelled(address guestAdress, uint256 bookingId) external view returns (bool);
    function getBookingCounts(address user) external view returns (uint256);
    function createBooking(uint256 roomID, uint256 checkInDate, uint256 checkOutDate) external;

}

interface IPaymentSmartContract {
    function processBookingPayment(address payable guestAddress, uint256 roomID, uint256 checkInDate, uint256 checkOutDate) external;
    function refundEscrow(address payable guestAddress, uint256 roomID, uint256 checkInDate) external;

}



contract GuestSmartContract {
    address public owner;
    IHotelSmartContract  public HotelSmartContract;
    IPaymentSmartContract public PaymentSmartContract;

    constructor(address payable HotelContractAddress, address PaymentContractAddress) {
        owner = HotelContractAddress;
        HotelSmartContract = IHotelSmartContract(HotelContractAddress);
        PaymentSmartContract = IPaymentSmartContract(PaymentContractAddress);
    }

    struct Room {
        uint256 id;
        string roomType;
        string description;
        uint256 price;
        string[] amenities;
        bool isAvailable;
    }

    struct Booking {
    uint256 roomID;
    uint256 roomIndex; // Index of the room in the rooms array
    uint256 checkInDate;
    uint256 checkOutDate;
    address guestAddress;
    bool confirmed;
    }

    event BookingCreated(address hotelAddress, uint256 bookingID);
    event BookingCancelled(address hotelAddress, uint256 bookingID, uint256 refundAmount);

     // Mapping: Address to Rooms
    mapping(address => Room[]) public rooms;
    // Mapping: Address to Booking ID to Booking
    mapping(address => mapping(uint256 => Booking)) public bookings;
    // Mapping: Address to Booking Count
    mapping(address => uint256) public bookingCounts;
    // Mapping: Address to Balance
    mapping(address => uint256) public balance;
    // Mapping: Address to Booking Room ID to Date to Availability
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) public bookedRooms;
    // Mapping: Address to Canceled Bookings (private)
    mapping(address => Booking[]) private canceledBookings;
    



    function createBooking(uint256 roomID, uint256 checkInDate, uint256 checkOutDate) public payable {
        // ... your booking logic ...
        require(HotelSmartContract.checkRoomAvailability(roomID, checkInDate, checkOutDate), "Room not available for these dates");
        require(msg.value >= (checkOutDate - checkInDate) * rooms[msg.sender][roomID].price, "Insufficient funds");

         uint256 roomIndex;
        // Find the index of the room in the rooms array
        for (uint256 i = 0; i < rooms[msg.sender].length; i++) {
            if (rooms[msg.sender][i].id == roomID) {
                roomIndex = i;
                break;
            }
        }

        // Set the room as unavailable
        rooms[msg.sender][roomIndex].isAvailable = false;

        Booking memory newBooking;
        newBooking.roomID = roomID;
        newBooking.roomIndex = roomIndex;
        newBooking.checkInDate = checkInDate;
        newBooking.checkOutDate = checkOutDate;
        newBooking.guestAddress = msg.sender;
        newBooking.confirmed = false;

        uint256 bookingID = bookingCounts[msg.sender];
        bookings[msg.sender][bookingID] = newBooking;
        bookingCounts[msg.sender]++;

        balance[msg.sender] += msg.value;

        emit BookingCreated(msg.sender, bookingID);

        // Mark the room as booked for the specified time period
        for (uint256 date = checkInDate; date <= checkOutDate; date++) {
            bookedRooms[owner][roomID][date] = true;
        }
    
        // Trigger payment processing in PaymentSmartContract
       // PaymentSmartContract paymentContract = IPaymentSmartContract;
        PaymentSmartContract.processBookingPayment(payable(msg.sender), roomID, checkInDate, checkOutDate);
    }

    function cancelBooking(uint256 bookingID) public {
        // ... your cancellation logic ...
        require(bookings[msg.sender][bookingID].guestAddress == msg.sender || msg.sender == owner, "Only guest or owner can cancel");

        Booking memory booking = bookings[msg.sender][bookingID];

        if (block.timestamp < booking.checkInDate - 7 days) {
            uint256 refundAmount = balance[msg.sender];

            
            // Set the room as available again
            rooms[msg.sender][booking.roomIndex].isAvailable = true;

            bookings[msg.sender][bookingID].confirmed = false;
            canceledBookings[msg.sender].push(booking);

            if (refundAmount > 0) {
                if (!payable(msg.sender).send(refundAmount)) {
                    revert("Withdrawal failed");
                }

                balance[msg.sender] += refundAmount;

                emit BookingCancelled(msg.sender, bookingID, refundAmount);
            } else {
                revert("Cancellation not allowed or no refund applicable");
            }
        }
        // Trigger refund processing in PaymentSmartContract
        //PaymentSmartContract paymentContract = PaymentSmartContract(/* address of PaymentSmartContract */);
        PaymentSmartContract.refundEscrow(payable(msg.sender), booking.roomID, booking.checkInDate);

    }
}