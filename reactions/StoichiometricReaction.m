
classdef StoichiometricReaction < ReactionModel
    %STOICHIOMETRICREACTION Represents a stoichiometric reaction model
    %
    % Copyright: © 2008-2015 Eric von Lieres, Joel Andersson, Andreas Püttmann, Sebastian Schnittert, Samuel Leweke
    %            See the license note at the end of the file.
    
    methods
        
        function obj = StoichiometricReaction()
            %STOICHIOMETRICREACTION Constructs a StoichiometricReaction object
            obj.name = 'STOICHIOMETRIC';
            obj.parameters = cell(6,1);

            obj.parameters{1} = ReactionModel.createParameter('NREACT', 'NREACT', false, false);
            obj.parameters{2} = ReactionModel.createParameter('REACTSTO_EXPL', 'EXPL', true, true);
            obj.parameters{3} = ReactionModel.createParameter('REACTSTO_EXPS', 'EXPS', true, true);
            obj.parameters{4} = ReactionModel.createParameter('REACTSTO_STOL', 'STOL', true, true);
            obj.parameters{5} = ReactionModel.createParameter('REACTSTO_STOS', 'STOS', true, true);
            obj.parameters{6} = ReactionModel.createParameter('REACTSTO_RATE', 'K', false, true);
        end

        function params = convertParametersToStruct(obj, params)
            %CONVERTPARAMETERSTOSTRUCT Converts the values of the given parameters to the required types specified in the file format
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: The struct with converted parameter values

            params.NREACT = int32(params.NREACT);
        end
        
        function params = convertParametersToProperty(obj, params)
            %CONVERTPARAMETERSTOPROPERTY Converts the values of the given parameters from the file format to the Matlab interface
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: The struct with converted parameter values

            params.NREACT = double(params.NREACT);
        end

        function ok = checkParameters(obj, params, nComponents)
            %CHECKPARAMETERS Checks the values of the given parameters for plausibility
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: True if the values are ok, otherwise false

            nReactions = params.NREACT;

            ok = ReactionModel.checkNonnegativeVector(params.NREACT, 1, 'NREACT');
            ok = ReactionModel.checkNonnegativeVector(params.REACTSTO_EXPL, nReactions * nComponents, 'REACTSTO_EXPL') && ok;
            ok = ReactionModel.checkNonnegativeVector(params.REACTSTO_EXPS, nReactions * nComponents, 'REACTSTO_EXPS') && ok;
            ok = ReactionModel.checkVectorSize(params.REACTSTO_STOL, nReactions * nComponents, 'REACTSTO_STOL') && ok;
            ok = ReactionModel.checkVectorSize(params.REACTSTO_STOS, nReactions * nComponents, 'REACTSTO_STOS') && ok;
            ok = ReactionModel.checkNonnegativeVector(params.REACTSTO_RATE, nReactions, 'REACTSTO_RATE') && ok;
        end
        
    end

end

% =============================================================================
%  CADET - The Chromatography Analysis and Design Toolkit
%  
%  Copyright © 2008-2015: Eric von Lieres¹, Joel Andersson,
%                         Andreas Puettmann¹, Sebastian Schnittert¹,
%                         Samuel Leweke¹
%                                      
%    ¹ Forschungszentrum Juelich GmbH, IBG-1, Juelich, Germany.
%  
%  All rights reserved. This program and the accompanying materials
%  are made available under the terms of the GNU Public License v3.0 (or, at
%  your option, any later version) which accompanies this distribution, and
%  is available at http://www.gnu.org/licenses/gpl.html
% =============================================================================
