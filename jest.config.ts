import type { Config } from 'jest';

const config: Config = {
    testEnvironment: 'node',
    testPathIgnorePatterns: ['/node_modules/', '/dist/'],
    transform: {
        "^.+\\.(t|j)sx?$": "@swc/jest",
    },
};

export default config;
