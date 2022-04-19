package main

import (
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/mattermost/mattermost-server/v6/model"
)

func TestServeHTTP(t *testing.T) {
	assert := assert.New(t)
	plugin := Plugin{}
	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "/", nil)

	plugin.ServeHTTP(nil, w, r)

	result := w.Result()
	assert.NotNil(result)
	defer result.Body.Close()
	bodyBytes, err := ioutil.ReadAll(result.Body)
	assert.Nil(err)
	bodyString := string(bodyBytes)

	b := assert.Equal("Hello, world!", bodyString)
}

func TestSetConfiguration(t *testing.T) {
	plugin := Plugin{}
	boolTrue := true
	stringRef := ""

	baseFeatureFlags := &model.FeatureFlags{}
	basePluginSettings := &model.PluginSettings{
		Directory: &stringRef,
	}
	driverName := "testDriver"
	dataSource := "testDirectory"
	baseSQLSettings := &model.SqlSettings{
		DriverName: &driverName,
		DataSource: &dataSource,
	}

	directory := "testDirectory"
	baseFileSettings := &model.FileSettings{
		DriverName: &driverName,
		Directory:  &directory,
	}

	baseConfig := &model.Config{
		FeatureFlags:   baseFeatureFlags,
		PluginSettings: *basePluginSettings,
		SqlSettings:    *baseSQLSettings,
		FileSettings:   *baseFileSettings,
	}

	t.Run("test enable telemetry", func(t *testing.T) {
		logSettings := &model.LogSettings{
			EnableDiagnostics: &boolTrue,
		}
		mmConfig := baseConfig
		mmConfig.LogSettings = *logSettings

		config := plugin.createBoardsConfig(*mmConfig, "", "testId")
		assert.Equal(t, true, config.Telemetry)
		assert.Equal(t, "testId", config.TelemetryID)
	})

	t.Run("test enable shared boards", func(t *testing.T) {
		mmConfig := baseConfig
		mmConfig.PluginSettings.Plugins = make(map[string]map[string]interface{})
		mmConfig.PluginSettings.Plugins[pluginName] = make(map[string]interface{})
		mmConfig.PluginSettings.Plugins[pluginName][sharedBoardsName] = true
		config := plugin.createBoardsConfig(*mmConfig, "", "")
		assert.Equal(t, true, config.EnablePublicSharedBoards)
	})

	t.Run("test boards feature flags", func(t *testing.T) {
		featureFlags := &model.FeatureFlags{
			TestFeature:        "test",
			TestBoolFeature:    boolTrue,
			BoardsFeatureFlags: "hello_world-myTest",
		}

		mmConfig := baseConfig
		mmConfig.FeatureFlags = featureFlags

		config := plugin.createBoardsConfig(*mmConfig, "", "")
		assert.Equal(t, "true", config.FeatureFlags["TestBoolFeature"])
		assert.Equal(t, "test", config.FeatureFlags["TestFeature"])

		assert.Equal(t, "true", config.FeatureFlags["hello_world"])
		assert.Equal(t, "true", config.FeatureFlags["myTest"])
	})
}
