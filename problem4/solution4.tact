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
    yesCount: Int as uint32;
    noCount: Int as uint32;
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
        let currentTime: Int = now();
        require(currentTime < msg.votingEndingAt, "Voting end time must be in the future");
        
        let proposalInit: ProposalInit = ProposalInit{
            master: myAddress(),
            proposalId: self.nextProposalId
        };
        
        deploy(DeployParameters{
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: beginCell().storeUint(msg.votingEndingAt, 32).endCell(),
            init: initOf Proposal(proposalInit)
        });
        
        self.nextProposalId += 1;
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
    yesCount: Int as uint32;
    noCount: Int as uint32;
    voters: map<Address, Bool>;
    totalVotes: Int as uint32;
    
    init(data: ProposalInit) {
        self.master = data.master;
        self.proposalId = data.proposalId;
        self.votingEndingAt = now() + 86400; // 24 hours from now
        self.yesCount = 0;
        self.noCount = 0;
        self.voters = emptyMap();
        self.totalVotes = 0;
    }

    /// @notice Handles the initial message to set voting end time
    /// @dev Only the master can set the voting end time
    receive(msg: Slice) {
        if (sender() != self.master) {
            throw(201);
        }
        
        self.votingEndingAt = msg.loadUint(32);
        
        let currentTime: Int = now();
        require(currentTime < self.votingEndingAt, "Voting end time must be in the future");
    }

    /// @notice Handles incoming votes
    /// @param msg Vote message containing the vote value
    /// @dev Throws:
    ///       102 if voting has ended
    ///       103 if max votes reached
    ///       104 if address has already voted
    receive(msg: Vote) {
        let currentTime: Int = now();
        require(currentTime < self.votingEndingAt, "Voting has ended");
        
        require(self.yesCount + self.noCount < 100, "Maximum number of votes reached");

        let voter: Address = sender();
        require(self.voters.get(voter) == null, "Already voted");
        
        self.voters.set(voter, true);
        
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
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

