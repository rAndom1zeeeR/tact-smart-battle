## Level 4: Master Contract for Multiple Voting Proposals + Refunds

### 1. Problem Statement

This problem is a follow-up on Level 2 (solution2.tact): we implement the same high-level logic, but this time handle funds more carefully.

Implement two contracts: the ProposalMaster contract acting as a proxy that deploys voting proposal contracts very similar to the Proposal contract from Level 1 (solution1.tact), which records users' votes as before.:

- The `ProposalMaster` contract acting as a proxy that deploys voting proposal contracts very similar to the Proposal contract from Level 1 (solution1.tact)
- The `Proposal` contract similar to Level 1, which records users' votes

#### Key Requirements:

- All contracts' receivers must return excess funds back to the wallet of the user who initiated the transaction.
- The `ProposalMaster` contract should have a top-up empty message receiver that increases the contract balance to 0.01 TON each time it is invoked. The contract should accept all the funds if the incoming message carries a smaller TON amount
- Each `Proposal` contract is identified by its master address and a unique `proposalId` number (starting from zero) and increase by one each time a new proposal is deployed.
- Anyone can deploy a new proposal contract via the `ProposalMaster` contract

#### Each deployed `Proposal` contract must satisfy the following requirements::

- The voting is time-limited: no more votes can be accepted after the specified duration.
- Only the first hundred (100) votes can be accepted
- No votes can be accepted after the voting deadline.
- A voter is uniquely identified by their blockchain address
- Any voter can vote only once
- A voter cannot change their mind and change how they cast their vote.
- If a vote is not accepted, an exit code indicating unsuccessful execution must be thrown.
- Your contracts' receivers should not consume too much gas: most tests won't send more than 0.1 Toncoin (the reference solution consumes way below this limit).
- The proposal contracts should reimburse the excess funds sent by voters: it cannot freeze funds, burn them, or send them to someone else.
- If someone tries to impersonate the `ProposalMaster` contract, the `Proposal` contract should throw exit code 2025

### 2. Interfaces

Your submission must adhere to the interfaces described below to ensure your contract can be tested automatically.

#### 2.1 File name and contract names

- File name: `solution4.tact`
- Contract names: `ProposalMaster` and `Proposal`
- Both contracts must be in the same file

#### 2.2 ProposalMaster contract

- `init()` function must not have any arguments One way to achieve this would be not to have an init() function at all. (https://docs.tact-lang.org/book/contracts/#init-function)
- An empty receiver should be available to deploy the ProposalMaster contract: (https://docs.tact-lang.org/book/receive/#receive-internal-messages)

```tact
receive() {
  // TODO: implement
}
```

- To deploy a new voting proposal the `ProposalMaster` contract must accept messages of the `DeployNewProposal` message type:

```tact
message DeployNewProposal {
    votingEndingAt: Int as uint32;
}
```

If the current Unix time is greater than the value of the votingEndingAt field, the new Proposal contract must not get deployed.

- The `ProposalMaster` contract needs to have a getter named `nextProposalId` to retrieve the id of the next proposal with the following signature:

```tact
get fun nextProposalId(): Int
```

#### 2.3 Proposal contract

- Your contract's init() function should receive a single argument of the following type: (https://docs.tact-lang.org/book/contracts/#init-function)

```tact
struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}
```

The `master` field record the address of the `ProposalMaster` contract that deployed the current voting proposal.
The `proposalId` field in the init structure ensures that more than one proposal contract can be deployed on the blockchain.

- The `Proposal` contracts need to be initialized with zero vote counts upon deployment.

To allow casting votes, your `Proposal` contracts need to have a receiver accepting the `Vote` message type:

```tact
message Vote { value: Bool }
```

- The `value` field of a `Vote` message means "yes" if it is `true`, or "no" otherwise.
  Your contract needs to have a getter named proposalState to retrieve the current voting results with the following signature:

```tact
get fun proposalState(): ProposalState
```

- This getter above needs to return the following `ProposalState` structure:

```tact
struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}
```

If the current Unix time is greater than the value of the votingEndingAt field, no more votes will be accepted by the Proposal contract which gets deployed with this deadline information.

## 2.4 Solution template

You can find the contract interfaces described above in solution4.tact. Notice that you can add new receivers to your contracts in addition to the ones specified in the template

### 3. Public Tests

For testing compatibility, refer to the public interface compatibility test: `public4.spec.ts`

Run tests with:

```bash
npm run test public4
```

The test script automatically compiles all Tact contracts before running the tests.

Good luck with implementing Level 4!
