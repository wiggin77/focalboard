package app

import (
	"reflect"
	"testing"

	"github.com/golang/mock/gomock"
	"github.com/mattermost/focalboard/server/model"
	"github.com/mattermost/focalboard/server/utils"
	"github.com/stretchr/testify/require"
)

func TestCreateCard(t *testing.T) {
	th, tearDown := SetupTestHelper(t)
	defer tearDown()

	board := &model.Board{
		ID: utils.NewID(utils.IDTypeBoard),
	}
	userID := utils.NewID(utils.IDTypeUser)

	props := makeProps(3)

	card := &model.Card{
		BoardID:      board.ID,
		CreatedBy:    userID,
		ModifiedBy:   userID,
		Title:        "test card",
		ContentOrder: []string{utils.NewID(utils.IDTypeBlock), utils.NewID(utils.IDTypeBlock)},
		Properties:   props,
	}
	block := model.Card2Block(card)

	t.Run("success scenario", func(t *testing.T) {
		th.Store.EXPECT().GetBoard(board.ID).Return(board, nil)
		th.Store.EXPECT().InsertBlock(gomock.AssignableToTypeOf(reflect.TypeOf(block)), userID).Return(nil)
		th.Store.EXPECT().GetMembersForBoard(board.ID).Return([]*model.BoardMember{}, nil)

		newCard, err := th.App.CreateCard(card, board.ID, userID, false)

		require.NoError(t, err)
		require.Equal(t, card.BoardID, newCard.BoardID)
		require.Equal(t, card.Title, newCard.Title)
		require.Equal(t, card.ContentOrder, newCard.ContentOrder)
		require.EqualValues(t, card.Properties, newCard.Properties)
	})

	t.Run("error scenario", func(t *testing.T) {
		th.Store.EXPECT().GetBoard(board.ID).Return(board, nil)
		th.Store.EXPECT().InsertBlock(gomock.AssignableToTypeOf(reflect.TypeOf(block)), userID).Return(blockError{"error"})

		newCard, err := th.App.CreateCard(card, board.ID, userID, false)

		require.Error(t, err, "error")
		require.Nil(t, newCard)
	})
}

func TestPatchCard(t *testing.T) {
	th, tearDown := SetupTestHelper(t)
	defer tearDown()

	board := &model.Board{
		ID: utils.NewID(utils.IDTypeBoard),
	}
	userID := utils.NewID(utils.IDTypeUser)

	props := makeProps(3)

	card := &model.Card{
		BoardID:      board.ID,
		CreatedBy:    userID,
		ModifiedBy:   userID,
		Title:        "test card for patch",
		ContentOrder: []string{utils.NewID(utils.IDTypeBlock), utils.NewID(utils.IDTypeBlock)},
		Properties:   copyProps(props),
	}

	newTitle := "patched"
	newIcon := "😀"
	newContentOrder := reverse(card.ContentOrder)

	cardPatch := &model.CardPatch{
		Title:             &newTitle,
		ContentOrder:      &newContentOrder,
		Icon:              &newIcon,
		UpdatedProperties: modifyProps(props),
		DeletedProperties: []string{firstKey(props)},
	}

	t.Run("success scenario", func(t *testing.T) {
		expectedPatchedCard := cardPatch.Patch(card)
		expectedPatchedBlock := model.Card2Block(expectedPatchedCard)

		var blockPatch *model.BlockPatch
		th.Store.EXPECT().GetBoard(board.ID).Return(board, nil)
		th.Store.EXPECT().PatchBlock(card.ID, gomock.AssignableToTypeOf(reflect.TypeOf(blockPatch)), userID).Return(nil)
		th.Store.EXPECT().GetMembersForBoard(board.ID).Return([]*model.BoardMember{}, nil)
		th.Store.EXPECT().GetBlock(card.ID).Return(expectedPatchedBlock, nil).AnyTimes()

		patchedCard, err := th.App.PatchCard(cardPatch, card.ID, userID, false)

		require.NoError(t, err)
		require.Equal(t, board.ID, patchedCard.BoardID)
		require.Equal(t, newTitle, patchedCard.Title)
		require.Equal(t, newIcon, patchedCard.Icon)
		require.Equal(t, newContentOrder, patchedCard.ContentOrder)
		// one property was deleted
		require.Len(t, patchedCard.Properties, len(props)-1)
		require.EqualValues(t, expectedPatchedCard.Properties, patchedCard.Properties)
	})

	t.Run("error scenario", func(t *testing.T) {
		var blockPatch *model.BlockPatch
		th.Store.EXPECT().GetBoard(board.ID).Return(board, nil)
		th.Store.EXPECT().PatchBlock(card.ID, gomock.AssignableToTypeOf(reflect.TypeOf(blockPatch)), userID).Return(blockError{"error"})

		patchedCard, err := th.App.PatchCard(cardPatch, card.ID, userID, false)

		require.Error(t, err, "error")
		require.Nil(t, patchedCard)
	})
}

// reverse is a helper function to copy and reverse a slice of strings.
func reverse(src []string) []string {
	out := make([]string, 0, len(src))
	for i := len(src) - 1; i >= 0; i-- {
		out = append(out, src[i])
	}
	return out
}

func makeProps(count int) map[string]any {
	props := make(map[string]any)
	for i := 0; i < count; i++ {
		props[utils.NewID(utils.IDTypeBlock)] = utils.NewID(utils.IDTypeBlock)
	}
	return props
}

func copyProps(m map[string]any) map[string]any {
	out := make(map[string]any)
	for k, v := range m {
		out[k] = v
	}
	return out
}

func modifyProps(m map[string]any) map[string]any {
	out := make(map[string]any)
	for k := range m {
		out[k] = utils.NewID(utils.IDTypeBlock)
	}
	return out
}

func firstKey(m map[string]any) string {
	for k := range m {
		return k
	}
	return ""
}