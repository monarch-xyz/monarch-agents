// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

/// @title ErrorsLib
library ErrorsLib {
    /// @notice Thrown when a zero address is passed as input.
    string internal constant ZERO_ADDRESS = "zero address";

    /// @notice Thrown when an unauthorized rebalancer tries to call a function.
    string internal constant UNAUTHORIZED_REBALANCER = "unauthorized rebalancer";

    /// @notice Thrown when agent is not authorized by the user.
    string internal constant AGENT_NOT_AUTHORIZED = "agent not authorized";

    /// @notice Thrown when the market is zero.
    string internal constant ZERO_MARKET = "zero market";

    /// @notice Thrown when the token is invalid.
    string internal constant INVALID_TOKEN = "invalid token";

    /// @notice Thrown when the delta is non-zero.
    string internal constant DELTA_NON_ZERO = "delta non-zero";

    /// @notice Thrown when marketID not enabled by user
    string internal constant NOT_ENABLED = "not-enabled";

    /// @notice Thrown when the length of the array is invalid.
    string internal constant INVALID_LENGTH = "invalid length";

    /// @notice Thrown when the cap is exceeded.
    string internal constant CAP_EXCEEDED = "cap exceeded";
}
