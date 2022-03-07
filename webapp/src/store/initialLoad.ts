// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import {createAsyncThunk, createSelector} from '@reduxjs/toolkit'

import {default as client} from '../octoClient'
import {Subscription} from '../wsclient'

import {RootState} from './index'

export const initialLoad = createAsyncThunk(
    'initialLoad',
    async () => {
        const [team, teams, boards, boardTemplates] = await Promise.all([
            client.getTeam(),
            client.getTeams(),
            client.getBoards(),
            client.getTeamTemplates(),
        ])

        return {
            team,
            teams,
            boards,
            boardTemplates,
        }
    },
)

export const initialReadOnlyLoad = createAsyncThunk(
    'initialReadOnlyLoad',
    async (boardId: string) => {
        const blocks = client.getSubtree(boardId, 3)
        return blocks
    },
)

export const loadBoardData = createAsyncThunk(
    'loadBoardData',
    async (boardID: string) => {
        const blocks = await client.getAllBlocks(boardID)
        return {
            blocks,
        }
    },
)

export const getUserBlockSubscriptions = (state: RootState): Array<Subscription> => state.users.blockSubscriptions

export const getUserBlockSubscriptionList = createSelector(
    getUserBlockSubscriptions,
    (subscriptions) => subscriptions,
)
