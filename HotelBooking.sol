// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



contract HotelBooking {

    address public owner;

    // Struct to represent a room
    struct Room {
        uint256 roomId;
        uint256 price;
        bool isBooked;
    }

    // Supported currencies
    enum Currency {ETH, BTC, USDC}

    // Mapping to store supported currencies
    mapping(Currency => bool) public supportedCurrencies;

    // Mapping to store available rooms
    mapping(uint256 => Room) public rooms;

    // Dynamic array to store room IDs
    uint256[] public roomIds;

    // Mapping to store room IDs and their index in the dynamic array
    mapping(uint256 => uint256) public roomIndex;

    // Mapping to store user booking history
    mapping(address => uint256[]) public userBookingHistory;

    // Mapping to store room IDs and their availability
    mapping(uint256 => bool) public roomIdsMapping;

    // Mapping to store booking IDs and their index in the dynamic array
    mapping(uint256 => uint256) public bookingIndex;

    // Array to store booking ids
    uint256[] public bookingIds;

    // Mapping to store user balances
    mapping(address => uint256) public balances;

    // Booking details
    struct Booking {
        uint256 bookingId;
        uint256 roomId;
        uint256 amountPaid;
        bool isActive;
        address guest; // Added to store the address of the guest who made the booking
    }

    // Mapping to store bookings
    mapping(uint256 => Booking) public bookings;

    // Booking fee
    uint256 public bookingFee;

    // Mapping of authorized addresses
    mapping(address => bool) public authorizedAddresses;

    // Events to log important actions
    event RoomAdded(uint256 roomId, uint256 price);
    event CurrencyAdded(Currency currency);
    event PaymentReceived(address payer, uint256 amount);
    event BookingFeeSet(uint256 fee);
    event BookingCreated(address guest, uint256 roomId, uint256 amount, uint256 bookingId);
    event BookingCanceled(address guest, uint256 bookingId, uint256 refundAmount);
    // Event to log ownership changes
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    // Owner-only modifier for access control
    modifier onlyOwnerOrAuthorized() {
        require(msg.sender == owner || authorizedAddresses[msg.sender], "Not authorized");
        _;
    }

    // Owner-only modifier for access control
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Constructor for HotelBooking, passing the initial owner to Ownable's constructor
    constructor() {
        owner = msg.sender;
        // Your initialization code, if any
    }

    // Function to add a room (Owner only)
    function addRoom(uint256 _roomId, uint256 _price) public onlyOwnerOrAuthorized {
        // Check if the room already exists
        require(rooms[_roomId].roomId == 0, "Room already exists");

        // Add the room
        rooms[_roomId] = Room(_roomId, _price, false);

        // Update roomIds array
        roomIds.push(_roomId);

        // Update roomIdsMapping
        roomIdsMapping[_roomId] = true;
        
        emit RoomAdded(_roomId, _price);
    }

    // Function to set supported currencies (Owner only)
    function setSupportedCurrency(Currency _currency) public onlyOwnerOrAuthorized {
        supportedCurrencies[_currency] = true;
        emit CurrencyAdded(_currency);
    }

    // Function to receive payment (Owner only)
    function receivePayment() public payable onlyOwner {
        emit PaymentReceived(msg.sender, msg.value);
    }

    // Function to set booking fee (Owner only)
    function setBookingFee(uint256 _fee) public onlyOwnerOrAuthorized {
        bookingFee = _fee;
        emit BookingFeeSet(_fee);
    }

    // Function to view bookings (Owner only)
    function viewBookings() public view onlyOwnerOrAuthorized returns (Booking[] memory) {
    /***    uint256 activeBookingCount = 0;

    *   // Count the number of active bookings
    *    for (uint256 i = 1; i <= bookingIds.length; i++) {
            uint256 bookingId = bookingIds[i];
            if (bookings[bookingId].isActive) {
                activeBookingCount++;
            }
        }

        // Create an array to store active bookings
        Booking[] memory activeBookings = new Booking[](activeBookingCount);
        uint256 index = 0;

        // Populate the array with active bookings
        for (uint256 i = 1; i <= bookingIds.length; i++) {
            uint256 bookingId = bookingIds[i];
            if (bookings[bookingId].isActive) {
                activeBookings[index] = bookings[bookingId];
                index++;
            }
        }

        return activeBookings; */

        uint256 bookingCount = bookingIds.length;
        Booking[] memory allBookings = new Booking[](bookingCount);

        for (uint256 i = 0; i < bookingCount; i++) {
            uint256 bookingId = bookingIds[i];
            allBookings[i] = bookings[bookingId];
        }

        return allBookings;
    }

    // Function to view user booking history (Owner only)
    function viewUserBookingHistory(address _user) public view onlyOwnerOrAuthorized returns (uint256[] memory) {
        return userBookingHistory[_user];
    }

    // Function to view available rooms
    function viewAvailableRooms() public view returns (Room[] memory) {
        uint256 availableRoomCount = 0;

        // Count the number of available rooms
        for (uint256 i = 0; i < roomIds.length; i++) {
            uint256 roomId = roomIds[i];
            if (!rooms[roomId].isBooked) {
                availableRoomCount++;
            }
        }

        // Create an array to store available rooms
        Room[] memory availableRooms = new Room[](availableRoomCount);
        uint256 index = 0;

        // Populate the array with available rooms
       for (uint256 i = 0; i < roomIds.length; i++) {
            uint256 roomId = roomIds[i];
            if (!rooms[roomId].isBooked) {
                availableRooms[index] = rooms[roomId];
                index++;
            }
        }

        return availableRooms;
    }

    // Function to create a booking
    function createBooking(uint256 _roomId) public payable {
        require(rooms[_roomId].roomId != 0, "Invalid room ID");
        require(!rooms[_roomId].isBooked, "Room is already booked");

        uint256 bookingId = userBookingHistory[msg.sender].length + 1;
        uint256 amountToPay = rooms[_roomId].price + bookingFee;

        // Deduct the amount from the user's balance
        require(msg.value >= amountToPay, "Insufficient funds sent");
        balances[msg.sender] -= amountToPay;

        // Add the amount to the owner's balance (replace 'owner()' with the actual owner's address)
        balances[owner] += amountToPay;

         // Check if there's excess payment and return it to the user
        uint256 excessPayment = msg.value - amountToPay;
        if (excessPayment > 0) {
            payable(msg.sender).transfer(excessPayment);
        }

        // Mark the room as booked
        rooms[_roomId].isBooked = true;

        // Record the booking details
        bookings[bookingId] = Booking(bookingId, _roomId, amountToPay, true, msg.sender);

        // Update user booking history
        userBookingHistory[msg.sender].push(bookingId);

        emit BookingCreated(msg.sender, _roomId, amountToPay, bookingId);
    }

    // Function to get details of the most recent booking for the caller
    function getRecentBookingDetails() public view returns (Booking memory) {
        require(userBookingHistory[msg.sender].length > 0, "No bookings for the user");

        // Retrieve the most recent booking ID for the caller
        uint256 mostRecentBookingId = userBookingHistory[msg.sender][userBookingHistory[msg.sender].length - 1];

        // Return the details of the most recent booking
        return bookings[mostRecentBookingId];
    }


    // Function to cancel a booking
    function cancelBooking(uint256 _bookingId) public {
        require(bookings[_bookingId].isActive, "Booking does not exist or already canceled");
        require(msg.sender == bookings[_bookingId].guest, "Only the guest can cancel the booking");

        uint256 refundAmount = rooms[bookings[_bookingId].roomId].price;

        // Refund the room price to the user
        payable(msg.sender).transfer(refundAmount);

        // Mark the booking as canceled
        bookings[_bookingId].isActive = false;

        emit BookingCanceled(msg.sender, _bookingId, refundAmount);
    }

    // Function to check if the caller is authorized
    function isAuthorized(address _caller) public view onlyOwnerOrAuthorized returns (bool) {
        return authorizedAddresses[_caller];
    }

    // Function to add an authorized address (Owner only)
    function addAuthorizedAddress(address _authorizedAddress) public onlyOwner {
        authorizedAddresses[_authorizedAddress] = true;
    }

    // Function to remove an authorized address (Owner only)
    function removeAuthorizedAddress(address _authorizedAddress) public onlyOwner {
        authorizedAddresses[_authorizedAddress] = false;
    }

    // Function to transfer ownership
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only the current owner can transfer ownership");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
