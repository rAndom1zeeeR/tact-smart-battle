/// @title ProposalInit
/// @notice Initialization data structure for Proposal contract
/// @param master Address of the ProposalMaster contract that deployed this proposal
/// @param proposalId Unique identifier for this proposal
struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

/// @title DeployNewProposal
/// @notice Message to deploy a new proposal contract
/// @param votingEndingAt Unix timestamp when voting ends
message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

/// @title Vote
/// @notice Message for casting a vote
/// @param value true for yes, false for no
message Vote {
    value: Bool;
}

/// @title ProposalState
/// @notice Current state of a proposal
/// @param master Address of the master contract
/// @param proposalId Unique identifier of this proposal
/// @param votingEndingAt Unix timestamp when voting ends
/// @param yesCount Number of yes votes
/// @param noCount Number of no votes
struct ProposalState {
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    yesCount: Int as uint8;
    noCount: Int as uint8;
}

const MIN_TON_FOR_STORAGE: Int = ton("0.01");
const GAS_FOR_VOTE: Int = ton("0.001");
const GAS_FOR_DEPLOY: Int = ton("0.05");
const MAX_VOTES: Int = 100;
const DEFAULT_VOTING_PERIOD: Int = 86400; // 24 hours in seconds

/// @title ProposalMaster
/// @notice Master contract that manages proposal deployment and voting
/// @dev Maintains a counter for proposal IDs and handles proposal deployment
contract ProposalMaster {
    // State variables
    nextProposalId: Int as uint32;
    
    init() {
        self.nextProposalId = 0;
    }

    /// @notice Handles top-up messages to maintain contract balance
    /// @dev Keeps up to 0.01 TON, refunds excess to sender
    receive() {
        let minBalance = MIN_TON_FOR_STORAGE;
        let curBalance = myBalance();
        let sender = sender();
        if (curBalance > minBalance) {
            let refund = curBalance - minBalance;
            if (refund > 0) {
                send(SendParameters{
                    to: sender,
                    value: refund,
                    mode: SendRemainingValue,
                    bounce: false
                });
            }
        }
    }

    /// @notice Deploys a new proposal contract
    /// @param msg DeployNewProposal message containing voting end time
    /// @dev Throws 101 if voting end time is invalid
    receive(msg: DeployNewProposal) {
        let now = now();
        if (msg.votingEndingAt <= now) {
            throw(101); // Invalid voting end time
        }
        
        let id = self.nextProposalId;
        let master = myAddress();
        let ctx = context();
        
        // Check if we have enough TON for deployment
        if (ctx.value < GAS_FOR_DEPLOY) {
            throw(102); // Not enough TON for deployment
        }
        
        // Deploy the new proposal contract using the deploy() function
        deploy(DeployParameters{
            init: initOf Proposal(ProposalInit{
                master: master,
                proposalId: id
            }),
            value: GAS_FOR_DEPLOY,
            bounce: true
        });
        
        self.nextProposalId = id + 1;
        
        // Refund any excess
        let refund = ctx.value - GAS_FOR_DEPLOY;
        if (refund > 0) {
            send(SendParameters{
                to: sender(),
                value: refund,
                mode: SendRemainingValue,
                bounce: false
            });
        }
    }

    /// @notice Returns the next available proposal ID
    /// @return Int The next proposal ID to be used
    get fun nextProposalId(): Int {
        return self.nextProposalId;
    }
}

/// @title Proposal
/// @notice Contract for managing a single voting proposal
/// @dev Handles vote recording and validation
contract Proposal {
    // State variables
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    yesCount: Int as uint8;
    noCount: Int as uint8;
    voters: map<Address, Bool>;
    totalVotes: Int as uint8;
    
    init(init: ProposalInit) {
        self.master = init.master;
        self.proposalId = init.proposalId;
        
        // Set default voting end time
        self.votingEndingAt = now() + DEFAULT_VOTING_PERIOD;
        
        self.yesCount = 0;
        self.noCount = 0;
        self.voters = emptyMap();
        self.totalVotes = 0;
    }

    /// @notice Handles incoming votes
    /// @param msg Vote message containing the vote value
    /// @dev Throws:
    ///       102 if voting has ended
    ///       103 if max votes reached
    ///       104 if address has already voted
    receive(msg: Vote) {
        let sender = sender();
        let now = now();
        if (now >= self.votingEndingAt) {
            throw(102); // Voting ended
        }
        if (self.totalVotes >= MAX_VOTES) {
            throw(103); // Max votes reached
        }
        if (self.voters.get(sender) != null) {
            throw(104); // Already voted
        }
        
        // Check if we have enough TON for the vote
        let ctx = context();
        if (ctx.value < GAS_FOR_VOTE) {
            throw(105); // Not enough TON for vote
        }
        
        // Record vote
        self.voters.set(sender, true);
        self.totalVotes += 1;
        
        // Set the appropriate counter to 1
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        
        // Refund excess
        let refund = ctx.value - GAS_FOR_VOTE;
        if (refund > 0) {
            send(SendParameters{
                to: sender,
                value: refund,
                mode: SendRemainingValue,
                bounce: false
            });
        }
    }

    /// @notice Returns the current state of the proposal
    /// @return ProposalState Current state including vote counts and metadata
    get fun proposalState(): ProposalState {
        return ProposalState{
            master: self.master,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt,
            yesCount: self.yesCount,
            noCount: self.noCount
        };
    }
}

