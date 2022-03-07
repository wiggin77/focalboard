// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import {createAsyncThunk, createSlice, PayloadAction} from '@reduxjs/toolkit'

import octoClient from '../octoClient'

import {Utils} from '../utils'

import {SuiteWindow} from '../types'

import {initialLoad} from './initialLoad'

import {RootState} from './index'

export interface Team {
    id: string
    title: string
    signupToken: string
    modifiedBy: string
    updateAt:number
}

export const fetchTeams = createAsyncThunk(
    'team/fetch',
    async () => octoClient.getTeams(),
)

export const regenerateSignupToken = createAsyncThunk(
    'team/regenerateSignupToken',
    async () => octoClient.regenerateTeamSignupToken(),
)

export const refreshCurrentTeam = createAsyncThunk(
    'team/refreshCurrentTeam',
    async () => octoClient.getTeam(),
)

type TeamState = {
    current: Team | null
    allTeams: Array<Team>
}

const teamSlice = createSlice({
    name: 'teams',
    initialState: {
        current: null,
        allTeams: [],
    } as TeamState,
    reducers: {
        setTeam: (state, action: PayloadAction<string>) => {
            const teamID = action.payload
            const team = state.allTeams.find((t) => t.id === teamID)
            if (!team) {
                Utils.log(`Unable to find team in store. TeamID: ${teamID}`)
                return
            }

            if (state.current === team) {
                return
            }

            state.current = team

            const suiteWindow = (window as SuiteWindow)
            if (suiteWindow.setTeamInSidebar) {
                suiteWindow.setTeamInSidebar(teamID)
            }
        },
    },
    extraReducers: (builder) => {
        builder.addCase(initialLoad.fulfilled, (state, action) => {
            state.current = action.payload.team
            state.allTeams = action.payload.teams
            state.allTeams.sort((a: Team, b: Team) => (a.title < b.title ? -1 : 1))

            const windowAny = (window as any)
            if (windowAny.setTeamInSidebar && action.payload?.team?.id) {
                windowAny.setTeamInSidebar(action.payload.team?.id)
            }
        })
        builder.addCase(fetchTeams.fulfilled, (state, action) => {
            state.allTeams = action.payload
            state.allTeams.sort((a: Team, b: Team) => (a.title < b.title ? -1 : 1))
        })
        builder.addCase(refreshCurrentTeam.fulfilled, (state, action) => {
            state.current = action.payload
        })
    },
})

export const {setTeam} = teamSlice.actions
export const {reducer} = teamSlice

export const getCurrentTeam = (state: RootState): Team|null => state.teams.current
export const getFirstTeam = (state: RootState): Team|null => state.teams.allTeams[0]
