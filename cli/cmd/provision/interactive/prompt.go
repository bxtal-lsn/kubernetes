package interactive

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/AlecAivazis/survey/v2"
)

// PromptText asks the user for text input
func PromptText(message string, defaultValue string) (string, error) {
	var result string

	prompt := &survey.Input{
		Message: message,
		Default: defaultValue,
	}

	err := survey.AskOne(prompt, &result)
	return result, err
}

// PromptPassword asks the user for a password input
func PromptPassword(message string) (string, error) {
	var result string

	prompt := &survey.Password{
		Message: message,
	}

	err := survey.AskOne(prompt, &result)
	return result, err
}

// PromptSelect asks the user to select from a list of options
func PromptSelect(message string, options []string) (string, error) {
	var result string

	prompt := &survey.Select{
		Message: message,
		Options: options,
	}

	err := survey.AskOne(prompt, &result)
	return result, err
}

// PromptConfirm asks the user for confirmation (yes/no)
func PromptConfirm(message string) (bool, error) {
	var result bool

	prompt := &survey.Confirm{
		Message: message,
	}

	err := survey.AskOne(prompt, &result)
	return result, err
}

// PromptInt asks the user for an integer value
func PromptInt(message string, defaultValue int) (int, error) {
	var result string

	prompt := &survey.Input{
		Message: message,
		Default: strconv.Itoa(defaultValue),
	}

	err := survey.AskOne(prompt, &result, survey.WithValidator(survey.Required))
	if err != nil {
		return 0, err
	}

	return strconv.Atoi(result)
}

// PromptIntWithRange asks the user for an integer value within a range
func PromptIntWithRange(message string, defaultValue, min, max int) (int, error) {
	for {
		val, err := PromptInt(message, defaultValue)
		if err != nil {
			return 0, err
		}

		if val < min || val > max {
			fmt.Printf("Value must be between %d and %d\n", min, max)
			continue
		}

		return val, nil
	}
}

// PromptYamlVariables prompts the user for values for a set of YAML variables
func PromptYamlVariables(variables map[string]interface{}) (map[string]interface{}, error) {
	result := make(map[string]interface{})

	for key, defaultValue := range variables {
		switch v := defaultValue.(type) {
		case string:
			val, err := PromptText(fmt.Sprintf("%s (%s)", key, v), v)
			if err != nil {
				return nil, err
			}
			result[key] = val

		case int:
			val, err := PromptInt(fmt.Sprintf("%s (%d)", key, v), v)
			if err != nil {
				return nil, err
			}
			result[key] = val

		case bool:
			val, err := PromptConfirm(fmt.Sprintf("%s (%t)", key, v))
			if err != nil {
				return nil, err
			}
			result[key] = val

		case []string:
			defaultStr := strings.Join(v, ", ")
			val, err := PromptText(fmt.Sprintf("%s (%s)", key, defaultStr), defaultStr)
			if err != nil {
				return nil, err
			}

			if val == defaultStr {
				result[key] = v
			} else {
				parts := strings.Split(val, ",")
				trimmed := make([]string, len(parts))
				for i, p := range parts {
					trimmed[i] = strings.TrimSpace(p)
				}
				result[key] = trimmed
			}

		default:
			// For complex types or unsupported types, just use the default
			result[key] = defaultValue
		}
	}

	return result, nil
}
