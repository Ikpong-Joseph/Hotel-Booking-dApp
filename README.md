# This Hotel Booking dApp was created with Solidity in the Remix IDE by utilizing chat GPT.

The first versions of the contract were separated into the Guest, Hotel, Reputation and PSC smart Contracts.

• Hotel smart contract held functions for the hotel owners.
• Guest smart contract for guests bookings and cancellations.
• Payment smart contract to receive payments from guests, transfer to owner or refund to Guest.
• Reputation smart contract for guest to leave reviews.

However due to the problem of running out of gas, I decided to strip out all functionally unnecessary functions from the smart contracts and to fuse the first 3 contracts into one; **HotelBooking.sol**

There are still some challenges faced such as the inability to read dates in human readable format by the contracts. Only Unix timestamps are processed by contracts.