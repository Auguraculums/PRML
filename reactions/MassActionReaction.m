
classdef MassActionReaction < ReactionModel
    %MASSACTIONREACTION Represents a mass action reaction model
    %
    % Copyright: © 2008-2015 Eric von Lieres, Joel Andersson, Andreas Püttmann, Sebastian Schnittert, Samuel Leweke
    %            See the license note at the end of the file.
    
    methods
        
        function obj = MassActionReaction()
            %MASSACTIONREACTION Constructs a MassActionReaction object
            obj.name = 'MASS_ACTION';
            obj.parameters = cell(6,1);

            obj.parameters{1} = ReactionModel.createParameter('NREACT', 'NREACT', false, false);
            obj.parameters{2} = ReactionModel.createParameter('REACTMA_AS', 'AS', true, true);
            obj.parameters{3} = ReactionModel.createParameter('REACTMA_AL', 'AL', true, true);
            obj.parameters{4} = ReactionModel.createParameter('REACTMA_BS', 'BS', true, true);
            obj.parameters{5} = ReactionModel.createParameter('REACTMA_BL', 'BL', true, true);
            obj.parameters{6} = ReactionModel.createParameter('REACTMA_RATE', 'RATE', false, true);
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
            ok = ReactionModel.checkNonnegativeVector(params.REACTMA_AS, nReactions * nComponents, 'REACTMA_AS') && ok;
            ok = ReactionModel.checkNonnegativeVector(params.REACTMA_AL, nReactions * nComponents, 'REACTMA_AL') && ok;
            ok = ReactionModel.checkNonnegativeVector(params.REACTMA_BS, nReactions * nComponents, 'REACTMA_BS') && ok;
            ok = ReactionModel.checkNonnegativeVector(params.REACTMA_BL, nReactions * nComponents, 'REACTMA_BL') && ok;
            ok = ReactionModel.checkNonnegativeVector(params.REACTMA_RATE, nReactions, 'REACTMA_RATE') && ok;
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
