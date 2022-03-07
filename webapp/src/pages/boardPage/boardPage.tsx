// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.
import React, {useEffect, useState, useMemo, useCallback} from 'react'
import {FormattedMessage, useIntl} from 'react-intl'
import {generatePath, useHistory, useRouteMatch} from 'react-router-dom'

import Workspace from '../../components/workspace'
import octoClient from '../../octoClient'
import {Utils} from '../../utils'
import wsClient from '../../wsclient'
import {getCurrentBoard, setCurrent as setCurrentBoard, fetchBoardMembers} from '../../store/boards'
import {getCurrentView, setCurrent as setCurrentView} from '../../store/views'
import {initialLoad, initialReadOnlyLoad, loadBoardData} from '../../store/initialLoad'
import {useAppSelector, useAppDispatch} from '../../store/hooks'
import {setTeam} from '../../store/teams'
import {setGlobalError} from '../../store/globalError'
import {UserSettings} from '../../userSettings'

import IconButton from '../../widgets/buttons/iconButton'
import CloseIcon from '../../widgets/icons/close'

import TelemetryClient, {TelemetryActions, TelemetryCategory} from '../../telemetry/telemetryClient'
import {fetchUserBlockSubscriptions, getMe} from '../../store/users'
import {IUser} from '../../user'

import SetWindowTitleAndIcon from './setWindowTitleAndIcon'
import TeamToBoardAndViewRedirect from './teamToBoardAndViewRedirect'
import UndoRedoHotKeys from './undoRedoHotKeys'
import BackwardCompatibilityQueryParamsRedirect from './backwardCompatibilityQueryParamsRedirect'
import WebsocketConnection from './websocketConnection'

import './boardPage.scss'

type Props = {
    readonly?: boolean
}

const BoardPage = (props: Props): JSX.Element => {
    const intl = useIntl()
    const board = useAppSelector(getCurrentBoard)
    const activeView = useAppSelector(getCurrentView)
    const dispatch = useAppDispatch()
    const match = useRouteMatch<{boardId: string, viewId: string, cardId?: string, teamId?: string}>()
    const [mobileWarningClosed, setMobileWarningClosed] = useState(UserSettings.mobileWarningClosed)
    const teamId = match.params.teamId || UserSettings.lastTeamId || '0'
    const me = useAppSelector<IUser|null>(getMe)
    const history = useHistory()

    // if we're in a legacy route and not showing a shared board,
    // redirect to the new URL schema equivalent
    if (Utils.isFocalboardLegacy() && !props.readonly) {
        window.location.href = window.location.href.replace('/plugins/focalboard', '/boards')
    }

    // Load user's block subscriptions when workspace changes
    // block subscriptions are relevant only in plugin mode.
    if (Utils.isFocalboardPlugin()) {
        useEffect(() => {
            if (!me) {
                return
            }

            dispatch(fetchUserBlockSubscriptions(me!.id))
        }, [teamId])
    }

    // TODO: Make this less brittle. This only works because this is the root render function
    useEffect(() => {
        UserSettings.lastTeamId = teamId
        octoClient.teamId = teamId
        wsClient.teamId = teamId
    }, [teamId])

    const loadAction: (boardId: string) => any = useMemo(() => {
        if (props.readonly) {
            return initialReadOnlyLoad
        }
        return initialLoad
    }, [props.readonly])

    const loadOrJoinBoard = useCallback(async (userId: string, boardTeamId: string, boardId: string, viewId: string) => {
        // set the active board if we're able to pick one
        dispatch(setCurrentBoard(boardId))

        // and fetch its data
        const result: any = await dispatch(loadBoardData(boardId))
        if (result.payload.blocks.length === 0) {
            const member = await octoClient.createBoardMember({userId, boardId})
            if (!member) {
                dispatch(setGlobalError('board-not-found'))
                return
            }
            await dispatch(loadBoardData(boardId))
        }

        dispatch(fetchBoardMembers({
            teamId: boardTeamId,
            boardId,
        }))

        // and set it as most recently viewed board
        UserSettings.setLastBoardID(boardTeamId, boardId)

        if (viewId && viewId !== '0') {
            dispatch(setCurrentView(viewId))
            UserSettings.setLastViewId(boardId, viewId)
        }
    }, [])

    useEffect(() => {
        dispatch(loadAction(match.params.boardId))

        if (match.params.boardId && me) {
            loadOrJoinBoard(me.id, teamId, match.params.boardId, match.params.viewId)
        }
    }, [teamId, match.params.boardId, match.params.viewId])

    if (props.readonly) {
        useEffect(() => {
            if (board?.id && activeView?.id) {
                TelemetryClient.trackEvent(TelemetryCategory, TelemetryActions.ViewSharedBoard, {board: board?.id, view: activeView?.id})
            }
        }, [board?.id, activeView?.id])
    }

    useEffect(() => {
        // This function is called when the user selected a team from the team sidebar.
        (window as any).setTeamInFocalboard = (newTeamID: string) => {
            // wsClient.unsubscribeToTeam(teamId)
            dispatch(setTeam(newTeamID))
            const params = {teamId: newTeamID}
            history.push(generatePath(match.path, params))
            wsClient.subscribeToTeam(newTeamID)
        }
    }, [])

    return (
        <div className='BoardPage'>
            <TeamToBoardAndViewRedirect/>
            <BackwardCompatibilityQueryParamsRedirect/>
            <SetWindowTitleAndIcon/>
            <UndoRedoHotKeys/>
            <WebsocketConnection
                teamId={teamId}
                boardId={match.params.boardId}
                readonly={props.readonly || false}
                loadAction={loadAction}
            />

            {!mobileWarningClosed &&
                <div className='mobileWarning'>
                    <div>
                        <FormattedMessage
                            id='Error.mobileweb'
                            defaultMessage='Mobile web support is currently in early beta. Not all functionality may be present.'
                        />
                    </div>
                    <IconButton
                        onClick={() => {
                            UserSettings.mobileWarningClosed = true
                            setMobileWarningClosed(true)
                        }}
                        icon={<CloseIcon/>}
                        title='Close'
                        className='margin-right'
                    />
                </div>}

            {props.readonly && board === undefined &&
                <div className='error'>
                    {intl.formatMessage({id: 'BoardPage.syncFailed', defaultMessage: 'Board may be deleted or access revoked.'})}
                </div>}
            <Workspace
                readonly={props.readonly || false}
            />
        </div>
    )
}

export default BoardPage
