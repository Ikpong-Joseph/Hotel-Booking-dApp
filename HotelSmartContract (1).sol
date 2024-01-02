// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract HotelSmartContract {
    address payable public owner;
    address[] public uniqueUsers;

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

    // Mapping: Address to Rooms
    mapping(address => Room[]) public rooms;
    // Mapping: Address to Booking ID to Booking
    mapping(address => mapping(uint256 => Booking)) public bookings;
    // Mapping: Address to Confirmed Bookings
    mapping(address => Booking[]) public confirmedBookings;
    // Mapping: Address to Canceled Bookings (private)
    mapping(address => Booking[]) private canceledBookings;
    // Mapping: Address to Balance
    mapping(address => uint256) public balance;
    // Mapping: Address to Booking Count
    mapping(address => uint256) public bookingCounts;
    // Mapping to store booked rooms for each time period
    // Mapping: Address to Booking Room ID to Date to Availability
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) public bookedRooms;

    mapping(address => uint256) public bookingFees;


    event RoomAdded(address hotelAddress, uint256 roomID);
    event BookingCreated(address hotelAddress, uint256 bookingID);
    event BookingConfirmed(address hotelAddress, uint256 bookingID);
    event BookingCancelled(address hotelAddress, uint256 bookingID, uint256 refundAmount);

    constructor() {
        owner = payable(msg.sender);
    }

    // Modifier to ensure that only the owner can call certain functions
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // The use of the onlyOwner modifier seems redundant.
    // I need specific detailed error messages
    // to explain why onlyOwner can call certain functions.

   

    function addRoom(uint256 id, string memory roomType, string memory description, uint256 price, string[] memory amenities) public {
        require(msg.sender == owner, "Only owner can add rooms");
        // Ensure that when filling the inputs for amenities;
        // Use no numbers
        // Use exactly this format: ["amenityOne", "amenityTwo", "amenityThree"]
        //This signifies that it is an array ( [] ) of strings ( "" ).
       

        Room memory newRoom;
        newRoom.id = id;
        newRoom.roomType = roomType;
        newRoom.description = description;
        newRoom.price = price;
        newRoom.amenities = amenities;
        newRoom.isAvailable = true;

       
        rooms[msg.sender].push(newRoom);

        emit RoomAdded(msg.sender, rooms[msg.sender].length - 1);
    }

    function setBookingFee(uint256 fee) public onlyOwner {
        bookingFees[address(this)] = fee;
    }

    function getRooms() public view returns (Room[] memory) {
        require(msg.sender == owner, "Only owner can get all rooms");
        return rooms[msg.sender];
    }

    function getUserRooms(address userAddress) public view returns (Room[] memory) {
        return rooms[userAddress];
    }

    function checkRoomAvailability(uint256 roomID, uint256 checkInDate, uint256 checkOutDate) public view returns (bool) {
        Room[] memory hotelRooms = rooms[owner];

        for (uint256 i = 0; i < hotelRooms.length; i++) {
            Room memory room = hotelRooms[i];

            if (room.id == roomID && room.isAvailable) {
                // Check if the room is booked during conflicting dates
                uint256 startDate = checkInDate > block.timestamp ? checkInDate : block.timestamp;
                uint256 endDate = checkOutDate;

                for (uint256 date = startDate; date <= endDate; date++) {
                    if (bookedRooms[owner][roomID][date]) {
                        return false; // Room is not available
                    }
                }

                return true; // Room is available
            }
        }

        return false; // Room not found
    }




    function createBooking(uint256 roomID, uint256 checkInDate, uint256 checkOutDate) public payable {
        require(checkRoomAvailability(roomID, checkInDate, checkOutDate), "Room not available for these dates");
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
    }

    function getBookingCount(address user) external view returns (uint256) {
        return bookingCounts[user];
    }

    function confirmBooking(uint256 bookingID) public {
        require(msg.sender == owner, "Only owner can confirm bookings");

        Booking storage bookingToConfirm = bookings[msg.sender][bookingID];

        require(!isBookingConfirmed(msg.sender, bookingToConfirm), "Booking already confirmed");

        bookingToConfirm.confirmed = true;
        confirmedBookings[msg.sender].push(bookingToConfirm);

        emit BookingConfirmed(msg.sender, bookingID);
    }

    function isBookingConfirmed(address user, Booking memory booking) internal view returns (bool) {
        Booking[] memory userConfirmedBookings = confirmedBookings[user];

        for (uint256 i = 0; i < userConfirmedBookings.length; i++) {
            if (userConfirmedBookings[i].roomID == booking.roomID &&
                userConfirmedBookings[i].checkInDate == booking.checkInDate &&
                userConfirmedBookings[i].checkOutDate == booking.checkOutDate) {
                return true;
            }
        }
        return false;
    }

    function cancelBooking(uint256 bookingID) public {
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
    }

    function isBookingCancelled(address guestAddress, uint256 bookingID) private view returns (bool) {
        if (canceledBookings[guestAddress].length > 0) {
            for (uint256 i = 0; i < canceledBookings[guestAddress].length; i++) {
                if (canceledBookings[guestAddress][i].roomID == bookingID) {
                    return true;
                }
            }
        }
        return false;
    }
}
